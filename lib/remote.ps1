# Optional upload of player.json to the remote MCP (T16, D20, D22). Off unless the user created
# remote.json (configure-remote). Uploads only the parsed snapshot and recent history entries,
# never the raw chat log. Dot-sourced by start.ps1 and configure-remote.ps1 after lib/common.ps1.
# Keep this file ASCII-only for Windows PowerShell 5.1.

# Push policy (D20): push on level/zone/subzone/quest/equipment change or a move of more than
# 3 map-percent, at most once per 30 s; heartbeat every 3 min when nothing changes.
$RemoteMinInterval=30
$RemoteHeartbeat=180
$RemoteMoveThreshold=3.0
$RemoteHistoryEntries=50

# Local, per-user file outside the repository. WOW_CONTEXT_REMOTE_CONFIG overrides it (tests).
function Get-RemoteConfigPath {
  if ($env:WOW_CONTEXT_REMOTE_CONFIG) { return $env:WOW_CONTEXT_REMOTE_CONFIG }
  if ((Test-IsWindows) -and $env:APPDATA) { return (Join-Path $env:APPDATA 'wow-context-bridge/remote.json') }
  if (Test-IsMac) { return (Join-Path $env:HOME 'Library/Application Support/wow-context-bridge/remote.json') }
  $base=$env:XDG_CONFIG_HOME; if (!$base) { $base=Join-Path $env:HOME '.config' }
  return (Join-Path $base 'wow-context-bridge/remote.json')
}

# Returns an error message for an unusable URL, or $null. HTTPS only, except http on this machine (tests).
function Test-RemoteUrl([string]$url) {
  if (!$url) { return 'url is empty' }
  $u=$null
  if (![Uri]::TryCreate($url,[UriKind]::Absolute,[ref]$u)) { return "not an absolute URL: $url" }
  if ($u.Scheme -eq 'https') { return $null }
  if ($u.Scheme -eq 'http' -and ($u.Host -eq '127.0.0.1' -or $u.Host -eq 'localhost')) { return $null }
  return 'url must start with https://'
}

# Returns the config object when uploading is enabled and valid, $null when off.
# Throws with a readable message when the file exists but is broken.
function Read-RemoteConfig([string]$path=(Get-RemoteConfigPath)) {
  if (!(Test-Path -LiteralPath $path)) { return $null }
  $c=[IO.File]::ReadAllText($path,(New-Object Text.UTF8Encoding($false))) | ConvertFrom-Json
  if (!$c.enabled) { return $null }
  $err=Test-RemoteUrl ([string]$c.url)
  if ($err) { throw "Remote upload config ${path}: $err" }
  if (([string]$c.uploadToken).Length -lt 32) { throw "Remote upload config ${path}: uploadToken missing or too short. Run configure-remote again." }
  return $c
}

function New-PushState {
  [pscustomobject]@{lastPushAt=$null;lastKey=$null;lastX=$null;lastY=$null;nextAttemptAt=0L;failures=0;lastError=$null}
}

function Get-PushKey($s) { return ((Get-Digest $s) | ConvertTo-Json -Depth 10 -Compress) }

function Get-MoveDistance($state,$s) {
  if ($null -eq $state.lastX -or $null -eq $state.lastY -or !$s.location) { return 0.0 }
  if ($null -eq $s.location.x -or $null -eq $s.location.y) { return 0.0 }
  $dx=[double]$s.location.x-[double]$state.lastX; $dy=[double]$s.location.y-[double]$state.lastY
  return [Math]::Sqrt($dx*$dx+$dy*$dy)
}

# Returns 'first', 'change', 'move', 'heartbeat' or 'none'. Compares with the last *pushed* state,
# so a change that arrives inside the 30 s window is pushed when the window ends.
function Get-PushDecision($state,$s,[long]$now) {
  if (!$s -or !$s.character) { return 'none' }
  if ($now -lt $state.nextAttemptAt) { return 'none' }
  if ($null -eq $state.lastPushAt) { return 'first' }
  $since=$now-[long]$state.lastPushAt
  $reason='none'
  if ((Get-PushKey $s) -ne $state.lastKey) { $reason='change' }
  elseif ((Get-MoveDistance $state $s) -gt $RemoteMoveThreshold) { $reason='move' }
  if ($reason -ne 'none') { if ($since -ge $RemoteMinInterval) { return $reason } else { return 'none' } }
  if ($since -ge $RemoteHeartbeat) { return 'heartbeat' }
  return 'none'
}

function Set-PushDone($state,$s,[long]$now) {
  $state.lastPushAt=$now; $state.lastKey=Get-PushKey $s
  $state.lastX=$null; $state.lastY=$null
  if ($s.location -and $null -ne $s.location.x -and $null -ne $s.location.y) { $state.lastX=[double]$s.location.x; $state.lastY=[double]$s.location.y }
  $state.failures=0; $state.nextAttemptAt=0L; $state.lastError=$null
}

# Back off 30 s, 60 s, 120 s ... up to 5 min after failures.
function Set-PushFailed($state,[long]$now,[string]$message) {
  $state.failures++
  $wait=[Math]::Min(300,$RemoteMinInterval*[Math]::Pow(2,$state.failures-1))
  $state.nextAttemptAt=$now+[long]$wait; $state.lastError=$message
}

# Last N history entries without the internal digest.
function Get-UploadHistory([string]$historyPath,[int]$limit=$RemoteHistoryEntries) {
  if (!$historyPath -or !(Test-Path -LiteralPath $historyPath)) { return ,@() }
  $lines=@([IO.File]::ReadAllLines($historyPath,(New-Object Text.UTF8Encoding($false))) | Where-Object { $_.Trim() })
  if ($lines.Count -gt $limit) { $lines=$lines[($lines.Count-$limit)..($lines.Count-1)] }
  $out=@()
  foreach ($l in $lines) {
    try { $e=$l | ConvertFrom-Json; $out+=[pscustomobject]@{capturedAt=$e.capturedAt;location=$e.location;changes=@($e.changes)} } catch { }
  }
  return ,$out
}

function Get-UploadBody($s,[string]$historyPath) {
  $hist=Get-UploadHistory $historyPath  # assign first: the function returns the array as one object
  return ([pscustomobject]@{snapshot=$s;history=$hist} | ConvertTo-Json -Depth 40 -Compress)
}

function Enable-Tls12 {
  if ($PSVersionTable.PSVersion.Major -lt 6) {
    try { [Net.ServicePointManager]::SecurityProtocol=[Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }
  }
}

function Get-RemoteEndpoint($cfg,[string]$path) { return (([string]$cfg.url).TrimEnd('/')+$path) }

# POSTs the body; returns $null on success or an error message.
function Send-RemoteUpload($cfg,[string]$body) {
  Enable-Tls12
  try {
    $bytes=(New-Object Text.UTF8Encoding($false)).GetBytes($body)
    $null=Invoke-RestMethod -Method Post -Uri (Get-RemoteEndpoint $cfg '/upload') -Headers @{Authorization=('Bearer '+$cfg.uploadToken)} -ContentType 'application/json; charset=utf-8' -Body $bytes -TimeoutSec 15
    return $null
  } catch {
    $code=$null
    try { $code=[int]$_.Exception.Response.StatusCode } catch { }
    if ($code -eq 401) { return 'upload token rejected (401): run configure-remote -SetSecrets, or check remote.json' }
    if ($code -eq 503) { return 'server not configured (503): set UPLOAD_TOKEN and READ_TOKEN with wrangler secret put' }
    if ($code) { return "HTTP $code" }
    return $_.Exception.Message
  }
}

# One policy step, called after every reader iteration. Returns the push reason, or '' if nothing was sent.
function Invoke-RemotePushStep($state,$cfg,$s,[string]$historyPath,[long]$now) {
  $reason=Get-PushDecision $state $s $now
  if ($reason -eq 'none') { return '' }
  $err=Send-RemoteUpload $cfg (Get-UploadBody $s $historyPath)
  if ($err) {
    $first=($state.failures -eq 0)
    Set-PushFailed $state $now $err
    if ($first) { Write-Warning "Remote upload failed: $err (retrying with backoff)" }
    return ''
  }
  if ($state.failures -gt 0) { Write-Host 'Remote upload working again.' }
  Set-PushDone $state $s $now
  return $reason
}
