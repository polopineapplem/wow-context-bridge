param(
  [string]$Url,
  [switch]$SetSecrets,
  [switch]$Check,
  [switch]$ShowConnector,
  [switch]$Disable,
  [switch]$Enable,
  [switch]$NewTokens,
  [string]$ConfigPath
)
# Sets up the optional remote upload (T16, D22). Writes remote.json OUTSIDE the repository
# (per-user app data folder) with the Worker URL and two random tokens:
#   uploadToken - used by start.ps1 to POST snapshots to /upload
#   readToken   - used by Claude (custom connector) to read /mcp
# Nothing is deployed or uploaded by this script unless you pass -SetSecrets (stores the tokens
# as Worker secrets via wrangler) or -Check (talks to your Worker).
# Keep this file ASCII-only for Windows PowerShell 5.1.
$ErrorActionPreference='Stop'
try { Remove-TypeData System.Array -ErrorAction Stop } catch { }
. (Join-Path $PSScriptRoot 'lib/common.ps1')
. (Join-Path $PSScriptRoot 'lib/remote.ps1')
$utf8=New-Object Text.UTF8Encoding($false)
if (!$ConfigPath) { $ConfigPath=Get-RemoteConfigPath }

function New-Token {
  $b=New-Object byte[] 32
  $rng=[Security.Cryptography.RandomNumberGenerator]::Create()
  try { $rng.GetBytes($b) } finally { $rng.Dispose() }
  return ([Convert]::ToBase64String($b).TrimEnd('=').Replace('+','-').Replace('/','_'))
}

function Read-Config {
  if (!(Test-Path -LiteralPath $ConfigPath)) { return $null }
  return ([IO.File]::ReadAllText($ConfigPath,$utf8) | ConvertFrom-Json)
}

function Save-Config($c) {
  $dir=Split-Path -Parent $ConfigPath
  if (!(Test-Path -LiteralPath $dir)) { $null=New-Item -ItemType Directory -Path $dir -Force }
  [IO.File]::WriteAllText($ConfigPath,($c | ConvertTo-Json -Depth 5),$utf8)
  if (!(Test-IsWindows)) { try { & chmod 600 $ConfigPath } catch { } }
}

function Normalize-Url([string]$u) {
  $u=$u.Trim().TrimEnd('/')
  if ($u -match '^(.*)/mcp(/[^/]*)?$') { $u=$Matches[1] }  # pasted the MCP address instead of the base
  return $u
}

function Show-Connector($c) {
  $base=([string]$c.url).TrimEnd('/')
  Write-Host ''
  Write-Host 'Claude (claude.ai, Desktop or mobile): Customize > Connectors > + Add > Add custom connector' -ForegroundColor Cyan
  Write-Host '  Authentication: No sign-in'
  Write-Host '  Option A - if the dialog has a "Request headers" section:'
  Write-Host "    MCP server URL: $base/mcp"
  Write-Host "    Header 'authorization', value: Bearer $($c.readToken)"
  Write-Host '  Option B - no "Request headers" section (the token is part of the URL):'
  Write-Host "    MCP server URL: $base/mcp/$($c.readToken)"
  Write-Host '  Anyone with the read token or the option B URL can read this character. Keep them private.' -ForegroundColor Yellow
  Write-Host '  New tokens: configure-remote -NewTokens -SetSecrets, then re-add the connector.'
}

function Set-WorkerSecrets($c) {
  $npx=Get-Command npx -ErrorAction SilentlyContinue
  if (!$npx) { throw 'npx (Node.js) not found. Install Node.js LTS from https://nodejs.org, then run again with -SetSecrets.' }
  Push-Location (Join-Path $PSScriptRoot 'remote')
  try {
    foreach ($pair in @(@('UPLOAD_TOKEN',$c.uploadToken),@('READ_TOKEN',$c.readToken))) {
      Write-Host "Setting Worker secret $($pair[0]) (wrangler secret put)..."
      $pair[1] | & $npx.Source --yes wrangler@4 secret put $pair[0]
      if ($LASTEXITCODE -ne 0) { throw "wrangler secret put $($pair[0]) failed. Run 'npx wrangler@4 login' in the remote folder first." }
    }
  } finally { Pop-Location }
}

function Test-Remote($c) {
  Enable-Tls12
  $base=([string]$c.url).TrimEnd('/')
  $ok=$true
  try {
    $null=Invoke-RestMethod -Method Get -Uri "$base/upload" -Headers @{Authorization=('Bearer '+$c.uploadToken)} -TimeoutSec 15
    Write-Host 'PASS upload token accepted' -ForegroundColor Green
  } catch { $ok=$false; Write-Host "FAIL upload check: $($_.Exception.Message)" -ForegroundColor Red }
  try {
    $req='{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"get_player_context","arguments":{}}}'
    $r=Invoke-RestMethod -Method Post -Uri "$base/mcp" -Headers @{Authorization=('Bearer '+$c.readToken);Accept='application/json, text/event-stream'} -ContentType 'application/json' -Body $req -TimeoutSec 15
    $ctx=$r.result.content[0].text | ConvertFrom-Json
    Write-Host "PASS read token accepted; remote data: $($ctx.freshness.summary) (age $($ctx.freshness.ageSeconds) s)" -ForegroundColor Green
  } catch { $ok=$false; Write-Host "FAIL MCP check: $($_.Exception.Message)" -ForegroundColor Red }
  if (!$ok) { Write-Host '401 = token mismatch (run with -SetSecrets); 503 = secrets not set; 404/DNS errors = wrong URL or not deployed.' }
  return $ok
}

$c=Read-Config
if ($Disable) {
  if (!$c) { Write-Host "Remote upload is already off (no $ConfigPath)."; exit 0 }
  $c.enabled=$false; Save-Config $c
  Write-Host 'Remote upload turned OFF. Restart the reader (start) for it to take effect. Data already on the Worker stays there until you delete the Worker.'
  exit 0
}
if (!$c) {
  if (!$Url) { $Url=Read-Host 'Worker URL printed by "wrangler deploy" (https://....workers.dev)' }
  $c=[pscustomobject]@{enabled=$true;url='';uploadToken=(New-Token);readToken=(New-Token)}
  Write-Host 'Generated new upload and read tokens.'
}
if ($Url) { $c.url=Normalize-Url $Url }
$err=Test-RemoteUrl ([string]$c.url)
if ($err) { Write-Host "Not saved: $err" -ForegroundColor Red; exit 1 }
if ($NewTokens) { $c.uploadToken=New-Token; $c.readToken=New-Token; Write-Host 'Generated new tokens (old ones stop working once the Worker secrets are updated).' }
if ($Enable -or $Url) { $c.enabled=$true }
Save-Config $c
Write-Host "Saved $ConfigPath (not in the repository). Upload: $(if ($c.enabled) { 'ON' } else { 'OFF' }) -> $($c.url)"

if ($SetSecrets) { Set-WorkerSecrets $c; Write-Host 'Worker secrets set.' -ForegroundColor Green }
$failed=$false
if ($Check) { if (!(Test-Remote $c)) { $failed=$true } }
if ($ShowConnector -or $SetSecrets -or !$Check) { Show-Connector $c }
if (!$SetSecrets -and !$Check) {
  Write-Host ''
  Write-Host 'Next: store the tokens on the Worker and test (needs Node.js; logs in to Cloudflare in your browser if needed):'
  Write-Host '  Windows: configure-remote.bat -SetSecrets -Check    macOS: ./configure-remote.command -SetSecrets -Check'
}
Write-Host 'Restart the reader (start) so it picks up the change.'
if ($failed) { exit 1 }
