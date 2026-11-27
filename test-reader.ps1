$ErrorActionPreference='Stop'
$tmpBase=if ($env:TEMP) { $env:TEMP } else { [IO.Path]::GetTempPath() }
$testRoot=Join-Path $tmpBase ('lcb-test-'+[guid]::NewGuid())
$null=New-Item -ItemType Directory $testRoot
$log=Join-Path $testRoot 'chat.txt'; $out=Join-Path $testRoot 'player.json'
$utf8=New-Object Text.UTF8Encoding($false)
# Never upload test data to a real Worker, even if this machine has remote upload turned on (D22).
$env:WOW_CONTEXT_REMOTE_CONFIG=Join-Path $testRoot 'no-remote.json'
$psExe=if (Get-Command powershell.exe -ErrorAction SilentlyContinue) { "powershell.exe" } else { (Get-Process -Id $PID).Path }
function Run-Reader {
  & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'start.ps1') -SkipInstall -Once -LogPath $log -OutputPath $out | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Reader failed' }
  return Get-Content -Raw -Encoding UTF8 $out | ConvertFrom-Json
}
function Check($condition,$label) { if (!$condition) { throw $label }; Write-Host "PASS $label" }
$s=Run-Reader
Check ($s.status -eq 'waiting_for_game' -and $s.freshness.stale) 'Missing log is waiting/stale, never fabricated data'
$sample=@{schemaVersion=1;capturedAt=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();session='123-456';sequence=1;character=@{name='亡灵 法师';class='法师';race='亡灵';level=22};quests=@(@{id=123;name='北方城堡的火炮';objectives=@(@{text='徽章：3/10';numFulfilled=3;numRequired=10})});equipment=@(@{slot=16;id=456;name='测试法杖'});completedQuestIDs=@(1,2)}
$hex= -join ($utf8.GetBytes(($sample | ConvertTo-Json -Depth 10 -Compress)) | ForEach-Object {$_.ToString('x2')})
$n=[int][Math]::Ceiling($hex.Length/700)
$lines=@('11/26 20:00:00.000  Player whispers: LCB1 123-456 1 1 1 deadbeef',('x'*65500))
for($i=1;$i -le $n;$i++) { $start=($i-1)*700; $lines+="11/26 20:00:00.000  LCB1 123-456 1 $i $n "+$hex.Substring($start,[Math]::Min(700,$hex.Length-$start)) }
[IO.File]::WriteAllText($log,($lines -join "`n")+"`n",$utf8)
$s=Run-Reader
Check ($s.character.name -eq '亡灵 法师' -and $s.quests[0].name -eq '北方城堡的火炮') 'Chinese UTF-8 round trip and chunks across read buffer'
Check ($s.equipment[0].id -eq 456 -and !$s.freshness.stale) 'Equipment and timestamp freshness'
Check (!(Get-Content -Raw $out).Contains('whispers')) 'Unrelated private chat excluded'
[IO.File]::WriteAllText($log,($lines[0..($lines.Length-2)] -join "`n")+"`n",$utf8)
$s=Run-Reader
Check ($s.status -eq 'waiting_for_game') 'Incomplete snapshot rejected'
$sample.capturedAt=1
$hex= -join ($utf8.GetBytes(($sample | ConvertTo-Json -Depth 10 -Compress)) | ForEach-Object {$_.ToString('x2')})
[IO.File]::WriteAllText($log,"LCB1 123-456 1 1 1 $hex`n",$utf8)
$s=Run-Reader
Check ($s.freshness.stale) 'Historical data marked stale'
[IO.File]::WriteAllText($log,"LCB1 123-456 1 1 1 ff`n",$utf8)
$s=Run-Reader
Check ($s.status -eq 'waiting_for_game') 'Invalid UTF-8 rejected'

# ---------- T1: start from the newest complete snapshot ----------
$hist=Join-Path $testRoot 'history.jsonl'
function Snap-Lines($session,$seq,$capturedAt,$level,$fulfilled,$weaponId,[switch]$Truncate) {
  $o=@{schemaVersion=1;capturedAt=$capturedAt;session=$session;sequence=$seq;character=@{name='亡灵 法师';class='法师';race='亡灵';level=$level};location=@{zone='贫瘠之地';subzone='十字路口';mapID=1413;x=51.4;y=30.2};quests=@(@{id=123;name='变异皮革';complete=$false;objectives=@(@{text="变异皮革：$fulfilled/20";numFulfilled=$fulfilled;numRequired=20})});equipment=@(@{slot=16;id=$weaponId;name="法杖$weaponId"});completedQuestIDs=@(1..200)}
  $h= -join ($utf8.GetBytes(($o | ConvertTo-Json -Depth 10 -Compress)) | ForEach-Object {$_.ToString('x2')})
  $n=[int][Math]::Ceiling($h.Length/700); $out=@()
  $last=$n; if ($Truncate) { $last=$n-1 }
  for($i=1;$i -le $last;$i++) { $st=($i-1)*700; $out+="11/27 10:00:00.000  LCB1 $session $seq $i $n "+$h.Substring($st,[Math]::Min(700,$h.Length-$st)) }
  for($i=1;$i -le 58;$i++) { $out+="11/27 10:00:00.000  LCB1PAD "+('z'*900) }
  return $out
}
function Write-Log($lines,[string]$tail='') { [IO.File]::WriteAllText($log,($lines -join "`n")+"`n"+$tail,$utf8) }
function Reset-Out { Remove-Item -LiteralPath $out,$hist -ErrorAction SilentlyContinue }
$now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$big=New-Object Collections.Generic.List[string]
for($q=1;$q -le 200;$q++) { $big.AddRange([string[]](Snap-Lines '100-111111' $q ($now-86400+$q) 22 ($q%20) 6505)) }
$newest=Snap-Lines '100-111111' 201 $now 23 9 7000
Write-Log ($big+$newest)
Reset-Out
$sizeMB=[Math]::Round((Get-Item $log).Length/1MB,1)
$sw=[Diagnostics.Stopwatch]::StartNew(); $s=Run-Reader; $sw.Stop()
Check ($s.sequence -eq 201 -and $s.character.level -eq 23 -and !$s.freshness.stale) "Large log ($sizeMB MB) starts at newest snapshot in $([int]$sw.Elapsed.TotalMilliseconds) ms"
Check (@([IO.File]::ReadAllLines($hist)).Count -eq 1) 'Historical snapshots are not replayed into history'

Write-Log ($big+(Snap-Lines '100-111111' 201 $now 23 9 7000 -Truncate)) 'LCB1 100-111111 202 1 9 abc'
Reset-Out; $s=Run-Reader
Check ($s.sequence -eq 200) 'Truncated newest snapshot and half line fall back to previous complete one'

Write-Log ($big+(Snap-Lines '200-222222' 1 $now 23 9 7000))
Reset-Out; $s=Run-Reader
Check ($s.session -eq '200-222222' -and $s.sequence -eq 1) 'Session change picks the new session'

$pad=@(); for($i=1;$i -le 5000;$i++) { $pad+="11/27 10:00:00.000  LCB1PAD "+('z'*900) }
Write-Log $pad
Reset-Out; $s=Run-Reader
Check ($s.status -eq 'waiting_for_game') 'Large log without any snapshot stays waiting'

# ---------- T2: history only on change ----------
Reset-Out
Write-Log (Snap-Lines '300-333333' 1 $now 22 9 6505); $null=Run-Reader
Write-Log ((Snap-Lines '300-333333' 1 $now 22 9 6505)+(Snap-Lines '300-333333' 2 ($now+1) 22 9 6505)); $null=Run-Reader
Check (@([IO.File]::ReadAllLines($hist)).Count -eq 1) 'Unchanged snapshot adds no history line'
Write-Log (Snap-Lines '300-333333' 3 ($now+2) 23 10 7000); $null=Run-Reader
$h=@([IO.File]::ReadAllLines($hist,$utf8))
$c=($h[-1] | ConvertFrom-Json).changes -join ' | '
Check ($h.Count -eq 2 -and $c -match 'level 22 -> 23' -and $c -match '9/20 -> 10/20' -and $c -match 'slot 16') "Change recorded: $c"

# ---------- Live tailing and log replacement ----------
Reset-Out
Write-Log (Snap-Lines '400-444444' 1 $now 22 9 6505)
$argLine='-NoProfile -ExecutionPolicy Bypass -File "{0}" -SkipInstall -Iterations 5 -LogPath "{1}" -OutputPath "{2}"' -f (Join-Path $PSScriptRoot 'start.ps1'),$log,$out
$spOpts=@{FilePath=$psExe;ArgumentList=$argLine;PassThru=$true}
if ($IsWindows -or $env:OS -eq 'Windows_NT') { $spOpts.WindowStyle='Hidden' }
$p=Start-Process @spOpts
Start-Sleep -Milliseconds 2500
[IO.File]::AppendAllText($log,((Snap-Lines '400-444444' 2 ($now+1) 22 11 6505) -join "`n")+"`n",$utf8)
Start-Sleep -Milliseconds 2500
$mid=Get-Content -Raw -Encoding UTF8 $out | ConvertFrom-Json
Write-Log (Snap-Lines '500-555555' 1 ($now+2) 22 12 6505)
$p.WaitForExit(20000) | Out-Null
$s=Get-Content -Raw -Encoding UTF8 $out | ConvertFrom-Json
Check ($mid.sequence -eq 2) 'Live tail picks up appended snapshot'
Check ($s.session -eq '500-555555') 'Shorter replaced log is rescanned'

Write-Host "Fixture tests only. Temporary test artifacts: $testRoot"
