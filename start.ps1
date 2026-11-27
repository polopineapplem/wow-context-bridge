param(
  [string]$GameRoot,
  [switch]$Once,
  [switch]$SkipInstall,
  [string]$LogPath,
  [string]$OutputPath,
  [string]$HistoryPath,
  [int]$HistoryLimit=500,
  [long]$BootstrapWindow=2MB,
  [int]$Iterations=0
)
# Keep this file ASCII-only: Windows PowerShell 5.1 reads BOM-less scripts as ANSI.
$ErrorActionPreference='Stop'
# Windows PowerShell 5.1: without this, ConvertTo-Json can emit arrays as {"value":[...],"Count":n}.
try { Remove-TypeData System.Array -ErrorAction Stop } catch { }
. (Join-Path $PSScriptRoot 'lib/common.ps1')
if (!$OutputPath) {
  $runtime=Get-RuntimeDir $PSScriptRoot
  if (!(Test-Path -LiteralPath $runtime)) { $null=New-Item -ItemType Directory -Path $runtime -Force }
  $OutputPath=Join-Path $runtime 'player.json'
}
if (!$SkipInstall -or !$LogPath) {
  try { $GameRoot=Resolve-ForeverRoot $GameRoot } catch { Write-Host $_.Exception.Message -ForegroundColor Yellow; exit 2 }
  Write-Host "Game folder: $GameRoot"
}
if (!$LogPath) { $LogPath=Join-Path $GameRoot 'Logs/WoWChatLog.txt' }
if (!$HistoryPath) { $HistoryPath=Join-Path (Split-Path -Parent ([IO.Path]::GetFullPath($OutputPath))) 'history.jsonl' }
$hash=[Security.Cryptography.SHA256]::Create()
$lockKey=([BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes([IO.Path]::GetFullPath($OutputPath))))).Replace('-','')
$mutex=New-Object Threading.Mutex($false,('Local\WoWContext-'+$lockKey))
try { $locked=$mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $locked=$true }
if (!$locked) { Write-Host 'Reader is already running for this output.'; exit 0 }
if (!$SkipInstall) {
  $addons=Join-Path $GameRoot 'Interface/AddOns'
  # Copy-Item into a missing folder would create AddOns as a copy of LocalContext itself.
  if (!(Test-Path -LiteralPath $addons)) { $null=New-Item -ItemType Directory -Path $addons -Force }
  Copy-Item (Join-Path $PSScriptRoot 'LocalContext') $addons -Recurse -Force
  Write-Host "Addon installed: $(Join-Path $addons 'LocalContext') (restart the game if it was already running)"
  # Keep the AI clients' copy of the MCP server current (macOS, checkout in a protected folder).
  try { $null=Sync-McpServer $PSScriptRoot } catch { Write-Warning "Could not refresh the MCP server copy: $($_.Exception.Message)" }
}
$utf8=New-Object System.Text.UTF8Encoding($false,$true)

# Parser state. "live" is false while the startup scan looks for the newest complete snapshot,
# so historical snapshots are never published (T1).
$offset=0L; $pending=''; $key=''; $parts=@{}; $expected=0; $state=$null
$live=$false; $bootstrapped=$false; $bootFound=$null; $dropFirst=$false; $readPos=0L; $lastDigest=$null

function Reset-Parser { $script:pending=''; $script:key=''; $script:parts=@{}; $script:expected=0; $script:dropFirst=$false }

function Save-State {
  if (!$script:state) { $script:state=[pscustomobject]@{schemaVersion=1;status='waiting_for_game';freshness=$null} }
  $now=[DateTimeOffset]::UtcNow
  $age=$null
  if ($script:state.PSObject.Properties['capturedAt']) { $age=$now.ToUnixTimeSeconds()-[long]$script:state.capturedAt }
  $script:state.freshness=[pscustomobject]@{checkedAt=$now.ToString('o');ageSeconds=$age;stale=($null -eq $age -or $age -gt 60 -or $age -lt -5);source='WoWChatLog'}
  $text=$script:state | ConvertTo-Json -Depth 30
  [IO.File]::WriteAllText("$OutputPath.tmp",$text,$utf8)
  Move-Item -LiteralPath "$OutputPath.tmp" -Destination $OutputPath -Force
}

# ---------- History (T2): append a line only when something meaningful changed ----------
function Get-Digest($s) {
  $quests=@()
  foreach ($q in @($s.quests)) {
    if ($null -eq $q) { continue }
    $progress=@()
    foreach ($o in @($q.objectives)) {
      if ($null -eq $o) { continue }
      if ($null -ne $o.numRequired -and [int]$o.numRequired -gt 0) { $progress+=('{0}/{1}' -f $o.numFulfilled,$o.numRequired) }
      elseif ($o.finished) { $progress+='done' } else { $progress+='todo' }
    }
    $quests+=[pscustomobject]@{id=$q.id;name=$q.name;complete=[bool]$q.complete;progress=($progress -join ',')}
  }
  $equip=@()
  foreach ($e in @($s.equipment)) { if ($null -ne $e -and $null -ne $e.id) { $equip+=[pscustomobject]@{slot=$e.slot;id=$e.id;name=$e.name} } }
  [pscustomobject]@{
    name=$s.character.name; level=$s.character.level
    mapID=$s.location.mapID; zone=$s.location.zone; subzone=$s.location.subzone
    quests=@($quests | Sort-Object id); equipment=@($equip | Sort-Object slot)
  }
}

function Compare-Digest($old,$new) {
  $changes=@()
  if ($null -eq $old) { return @('baseline') }
  if ($old.name -ne $new.name) { return @("character $($old.name) -> $($new.name)") }
  if ($old.level -ne $new.level) { $changes+="level $($old.level) -> $($new.level)" }
  if ($old.zone -ne $new.zone -or $old.subzone -ne $new.subzone) { $changes+="location $($old.zone)/$($old.subzone) -> $($new.zone)/$($new.subzone)" }
  $oldQ=@{}; foreach ($q in @($old.quests)) { if ($q) { $oldQ[[string]$q.id]=$q } }
  $newQ=@{}; foreach ($q in @($new.quests)) { if ($q) { $newQ[[string]$q.id]=$q } }
  foreach ($id in $newQ.Keys) {
    $n=$newQ[$id]
    if (!$oldQ.ContainsKey($id)) { $changes+="quest added $id $($n.name)"; continue }
    $o=$oldQ[$id]
    if ($o.progress -ne $n.progress) { $changes+="quest progress $id $($n.name): $($o.progress) -> $($n.progress)" }
    if ([bool]$o.complete -ne [bool]$n.complete) { $changes+="quest complete $id $($n.name): $($o.complete) -> $($n.complete)" }
  }
  foreach ($id in $oldQ.Keys) { if (!$newQ.ContainsKey($id)) { $changes+="quest removed $id $($oldQ[$id].name)" } }
  $oldE=@{}; foreach ($e in @($old.equipment)) { if ($e) { $oldE[[string]$e.slot]=$e } }
  $newE=@{}; foreach ($e in @($new.equipment)) { if ($e) { $newE[[string]$e.slot]=$e } }
  foreach ($slot in (@($oldE.Keys)+@($newE.Keys) | Sort-Object -Unique)) {
    $o=$oldE[$slot]; $n=$newE[$slot]
    $oid=$null; if ($o) { $oid=$o.id }
    $nid=$null; if ($n) { $nid=$n.id }
    if ($oid -ne $nid) {
      $oname='(empty)'; if ($o) { $oname=$o.name }
      $nname='(empty)'; if ($n) { $nname=$n.name }
      $changes+="equipment slot $slot $oname -> $nname"
    }
  }
  return $changes
}

function Load-LastDigest {
  if (!(Test-Path -LiteralPath $HistoryPath)) { return }
  try {
    $last=$null
    foreach ($l in [IO.File]::ReadAllLines($HistoryPath,$utf8)) { if ($l.Trim()) { $last=$l } }
    if ($last) { $script:lastDigest=($last | ConvertFrom-Json).digest }
  } catch { Write-Warning 'history.jsonl unreadable; starting a new baseline.'; $script:lastDigest=$null }
}

function Update-History($s) {
  $digest=Get-Digest $s
  $changes=@(Compare-Digest $script:lastDigest $digest)
  if ($changes.Count -eq 0) { return }
  $entry=[pscustomobject]@{
    capturedAt=$s.capturedAt; session=$s.session; sequence=$s.sequence
    location=[pscustomobject]@{zone=$s.location.zone;subzone=$s.location.subzone;mapID=$s.location.mapID;x=$s.location.x;y=$s.location.y}
    changes=$changes; digest=$digest
  }
  [IO.File]::AppendAllText($HistoryPath,($entry | ConvertTo-Json -Depth 10 -Compress)+"`n",$utf8)
  $script:lastDigest=$digest
  $all=[IO.File]::ReadAllLines($HistoryPath,$utf8)
  if ($all.Length -gt $HistoryLimit+50) {
    [IO.File]::WriteAllText("$HistoryPath.tmp",(($all[($all.Length-$HistoryLimit)..($all.Length-1)]) -join "`n")+"`n",$utf8)
    Move-Item -LiteralPath "$HistoryPath.tmp" -Destination $HistoryPath -Force
  }
}

# ---------- Log parsing ----------
function Publish($obj) {
  $script:state=$obj
  try { Update-History $obj } catch { Write-Warning "History update failed: $_" }
  Save-State
  Write-Host ('{0} snapshot seq={1} level={2} {3}/{4} quests={5}' -f [DateTimeOffset]::FromUnixTimeSeconds([long]$obj.capturedAt).ToLocalTime().ToString('HH:mm:ss'),$obj.sequence,$obj.character.level,$obj.location.zone,$obj.location.subzone,@($obj.quests).Count)
}

function Accept-Snapshot($obj) {
  $obj | Add-Member freshness $null -Force
  $obj | Add-Member status 'snapshot_received' -Force
  if ($script:live) { Publish $obj } else { $script:bootFound=$obj }
}

function Handle-Line([string]$line) {
  # Exact system-message payload or timestamp + payload, never player chat.
  if ($line -notmatch '^(?:\d+/\d+ \d+:\d+:\d+\.\d+\s+)?LCB1 ([0-9]+-[0-9]+) ([0-9]+) ([0-9]+) ([0-9]+) ([0-9a-f]+)\r?$') { return }
  $newKey=$Matches[1]+':'+$Matches[2]; $index=[int]$Matches[3]; $total=[int]$Matches[4]; $payload=$Matches[5]
  if ($total -lt 1 -or $total -gt 4096 -or $index -lt 1 -or $index -gt $total -or $payload.Length%2) { return }
  if ($newKey -ne $script:key) { $script:key=$newKey; $script:parts=@{}; $script:expected=$total }
  if ($script:expected -ne $total) { $script:parts=@{}; return }
  $script:parts[$index]=$payload
  if ($script:parts.Count -ne $total) { return }
  try {
    $p=$script:parts
    $hex= -join (1..$total | ForEach-Object { $p[$_] })
    $raw=New-Object byte[] ($hex.Length/2)
    for ($j=0;$j -lt $raw.Length;$j++) { $raw[$j]=[Convert]::ToByte($hex.Substring($j*2,2),16) }
    $obj=$utf8.GetString($raw) | ConvertFrom-Json
    if ($obj.schemaVersion -ne 1 -or !$obj.character -or !$obj.capturedAt -or ($obj.session+':'+$obj.sequence) -ne $script:key) { throw 'Invalid snapshot' }
  } catch { Write-Warning 'Rejected incomplete or invalid context snapshot.'; $script:parts=@{}; return }
  $script:parts=@{}
  Accept-Snapshot $obj
}

function Feed-Text([string]$text) {
  $script:pending += $text
  if ($script:dropFirst) {
    # Started mid-file: discard the partial first line.
    $i=$script:pending.IndexOf("`n")
    if ($i -lt 0) { $script:pending=''; return }
    $script:pending=$script:pending.Substring($i+1); $script:dropFirst=$false
  }
  $lines=$script:pending.Split("`n"); $script:pending=$lines[-1]
  for ($k=0;$k -lt $lines.Length-1;$k++) { Handle-Line $lines[$k] }
  if ($script:pending.Length -gt 16384) { $script:pending='' }
}

function Read-Range($f,[long]$from,[long]$to) {
  $null=$f.Seek($from,'Begin'); $pos=$from
  $buf=New-Object byte[] 65536
  while ($to -lt 0 -or $pos -lt $to) {
    $want=$buf.Length
    if ($to -ge 0) { $want=[int][Math]::Min([long]$buf.Length,$to-$pos) }
    $count=$f.Read($buf,0,$want)
    if ($count -le 0) { break }
    $pos+=$count
    Feed-Text ([Text.Encoding]::ASCII.GetString($buf,0,$count))
  }
  $script:readPos=$pos
}

function Start-FromTail($f) {
  # T1: scan growing windows from the end until the newest complete snapshot is found.
  $len=$f.Length; $window=[long]$BootstrapWindow; $script:live=$false; $script:bootFound=$null
  while ($true) {
    $start=[Math]::Max(0L,$len-$window)
    Reset-Parser; $script:bootFound=$null
    $script:dropFirst=($start -gt 0)
    Read-Range $f $start $len
    if ($script:bootFound -or $start -eq 0) { break }
    $window*=4
  }
  # Keep partial segments and the partial last line: live reading continues from $len.
  $script:offset=$len; $script:live=$true; $script:bootstrapped=$true
  if ($script:bootFound) { Publish $script:bootFound; $script:bootFound=$null }
}

Write-Host "Local context reader. Log: $LogPath"
Write-Host "Output: $OutputPath  History: $HistoryPath"
Write-Host 'Start/login to Forever normally. No copying or commands required. Ctrl+C stops reader.'
Write-Host 'Addon enables local chat logging, including whispers. It sends no network data.'
Load-LastDigest
$iteration=0
do {
  if (Test-Path -LiteralPath $LogPath) {
    $f=[IO.File]::Open($LogPath,'Open','Read','ReadWrite')
    try {
      if (!$bootstrapped -or $f.Length -lt $offset) { Start-FromTail $f }
      else { Read-Range $f $offset -1; $offset=$readPos }
    } finally { $f.Dispose() }
  }
  Save-State
  $iteration++
  if ($Once -or ($Iterations -gt 0 -and $iteration -ge $Iterations)) { break }
  Start-Sleep -Seconds 2
} while ($true)
