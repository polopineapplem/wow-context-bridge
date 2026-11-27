param(
  [string]$GameRoot,
  [string]$PlayerPath,
  [string]$ClaudeConfigPath,
  [string]$CodexConfigPath,
  [switch]$Json
)
# Read-only setup check for people and AI agents. Changes nothing.
# Prints PASS / WARN / FAIL per step with the fix; exit code 1 if any FAIL.
# Keep this file ASCII-only for Windows PowerShell 5.1.
$ErrorActionPreference='Stop'
try { Remove-TypeData System.Array -ErrorAction Stop } catch { }
. (Join-Path $PSScriptRoot 'lib/common.ps1')
$utf8=New-Object Text.UTF8Encoding($false)
if (!$PlayerPath) { $PlayerPath=Join-Path $PSScriptRoot 'player.json' }
$server=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'mcp-server.ps1'))
$results=New-Object Collections.Generic.List[object]
function Add-Result($step,$status,$detail,$fix) {
  $results.Add([pscustomobject]@{step=$step;status=$status;detail=$detail;fix=$fix})
}
function Sha([string]$path) {
  $h=[Security.Cryptography.SHA256]::Create()
  $s=[IO.File]::OpenRead($path)
  try { return [BitConverter]::ToString($h.ComputeHash($s)) } finally { $s.Dispose() }
}

# 1. Platform
if (Test-IsWindows) { Add-Result 'platform' 'PASS' ("Windows, PowerShell " + $PSVersionTable.PSVersion) '' }
elseif (Test-IsMac) { Add-Result 'platform' 'PASS' ("macOS, PowerShell " + $PSVersionTable.PSVersion) '' }
else { Add-Result 'platform' 'WARN' 'Not Windows or macOS: untested.' 'Run this on the computer that runs the game.' }

# 2. Game folder
$root=$null
try { $root=Resolve-ForeverRoot $GameRoot; Add-Result 'game folder' 'PASS' $root '' }
catch { Add-Result 'game folder' 'FAIL' $_.Exception.Message 'Run start.bat (Windows) or start.command (macOS) with -GameRoot set to the _forever_ folder.' }

if ($root) {
  # 3. Addon installed and current
  $installed=Join-Path $root 'Interface/AddOns/LocalContext/LocalContext.lua'
  $repoLua=Join-Path $PSScriptRoot 'LocalContext/LocalContext.lua'
  if (!(Test-Path -LiteralPath $installed)) { Add-Result 'addon' 'FAIL' 'LocalContext addon is not installed.' 'Run start.bat or start.command (it copies the addon), then fully restart the game.' }
  elseif ((Sha $installed) -ne (Sha $repoLua)) { Add-Result 'addon' 'WARN' 'Installed addon differs from this checkout.' 'Run start.bat or start.command to update it, then restart the game or /reload.' }
  else { Add-Result 'addon' 'PASS' 'Installed and matches this checkout.' '' }

  # 4. Game is writing LCB1 lines
  $log=Join-Path $root 'Logs/WoWChatLog.txt'
  if (!(Test-Path -LiteralPath $log)) { Add-Result 'game log' 'FAIL' 'WoWChatLog.txt does not exist yet.' 'Restart the game after installing the addon and log in to a character.' }
  else {
    $fi=Get-Item -LiteralPath $log
    $f=[IO.File]::Open($log,'Open','Read','ReadWrite')
    try {
      $n=[long][Math]::Min([long]$f.Length,[long]2MB); $null=$f.Seek($f.Length-$n,'Begin')
      $buf=New-Object byte[] $n; $read=0
      while ($read -lt $n) { $c=$f.Read($buf,$read,$n-$read); if ($c -le 0) { break }; $read+=$c }
      $tail=[Text.Encoding]::ASCII.GetString($buf,0,$read)
    } finally { $f.Dispose() }
    $mins=[int]([DateTime]::Now-$fi.LastWriteTime).TotalMinutes
    if ($tail -match 'LCB1 [0-9]+-[0-9]+ ') { Add-Result 'game log' 'PASS' "Addon data present; log last written $mins min ago." '' }
    else { Add-Result 'game log' 'FAIL' 'No addon data in the recent log.' 'Fully restart the game so it loads LocalContext, then log in to a character.' }
  }
}

# 5. Reader output
if (!(Test-Path -LiteralPath $PlayerPath)) { Add-Result 'reader' 'FAIL' 'player.json not found.' 'Run start.bat (Windows) or start.command (macOS) and keep its window open.' }
else {
  try {
    $p=[IO.File]::ReadAllText($PlayerPath,$utf8) | ConvertFrom-Json
    $now=[DateTimeOffset]::UtcNow
    $lag=$null
    if ($p.freshness -and $p.freshness.checkedAt) { $lag=[int]($now-[DateTimeOffset]::Parse([string]$p.freshness.checkedAt,[Globalization.CultureInfo]::InvariantCulture)).TotalSeconds }
    if ($null -eq $lag -or $lag -gt 15) { Add-Result 'reader' 'FAIL' "Reader is not running (player.json last refreshed $lag s ago)." 'Run start.bat (Windows) or start.command (macOS) and keep its window open.' }
    elseif ($p.status -ne 'snapshot_received') { Add-Result 'reader' 'WARN' 'Reader is running but has no character data yet.' 'Log in to a character in the game; wait about 20 seconds.' }
    else {
      $age=$now.ToUnixTimeSeconds()-[long]$p.capturedAt
      if ($age -gt 60) { Add-Result 'reader' 'WARN' "Last snapshot is $age s old." 'Normal in combat, loading screens or when logged out. Otherwise check the game log step.' }
      else { Add-Result 'reader' 'PASS' ("Live: {0}, level {1}, {2}; {3} s old." -f $p.character.name,$p.character.level,$p.location.zone,$age) '' }
    }
  } catch { Add-Result 'reader' 'FAIL' 'player.json is unreadable.' 'Restart start.bat or start.command.' }
}

# 6. MCP server answers
try {
  $psi=New-Object Diagnostics.ProcessStartInfo
  $psi.FileName=(Get-Process -Id $PID).Path
  $psi.Arguments=('-NoProfile -ExecutionPolicy Bypass -File "{0}" -PlayerPath "{1}"' -f $server,$PlayerPath)
  $psi.UseShellExecute=$false; $psi.RedirectStandardInput=$true; $psi.RedirectStandardOutput=$true; $psi.RedirectStandardError=$true
  $proc=[Diagnostics.Process]::Start($psi)
  $in=New-Object IO.StreamWriter($proc.StandardInput.BaseStream,$utf8)
  $in.Write('{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"check-setup","version":"1"}}}'+"`n")
  $in.Write('{"jsonrpc":"2.0","id":2,"method":"tools/list"}'+"`n")
  $in.Close()
  $out=$proc.StandardOutput.ReadToEnd(); $null=$proc.WaitForExit(20000)
  $lines=@($out -split "`n" | Where-Object { $_.Trim() })
  $toolCount=0
  if ($lines.Count -ge 2) { $toolCount=@((($lines[1] | ConvertFrom-Json).result.tools)).Count }
  if ($toolCount -ge 4) { Add-Result 'mcp server' 'PASS' "mcp-server.ps1 responds with $toolCount tools." '' }
  else { Add-Result 'mcp server' 'FAIL' 'mcp-server.ps1 did not answer correctly.' 'Make sure the whole repository was downloaded; run tests/test_mcp.py.' }
} catch { Add-Result 'mcp server' 'FAIL' "Could not start mcp-server.ps1: $($_.Exception.Message)" 'Make sure the whole repository was downloaded.' }

# 7. Client configuration
function Test-Points([string]$text) { return ($text -and $text.Replace('\\','\').ToLowerInvariant().Contains($server.ToLowerInvariant())) }
$claude=$ClaudeConfigPath; if (!$claude) { $claude=Find-ClaudeConfigPath }
$codex=$CodexConfigPath; if (!$codex) { $codex=Find-CodexConfigPath }
$configured=0
foreach ($c in @(@{name='Claude Desktop';path=$claude},@{name='Codex / ChatGPT desktop';path=$codex})) {
  if ($c.path -and (Test-Path -LiteralPath $c.path) -and (Test-Points ([IO.File]::ReadAllText($c.path,$utf8)))) {
    Add-Result "client: $($c.name)" 'PASS' "Configured in $($c.path)" ''; $configured++
  } else {
    Add-Result "client: $($c.name)" 'WARN' 'Not configured for this checkout.' 'Run install-mcp.bat (Windows) or install-mcp.command (macOS), then fully quit and reopen the client.'
  }
}
if ($configured -eq 0) { Add-Result 'ai client' 'FAIL' 'No AI client is configured to use this checkout.' 'Run install-mcp.bat (Windows) or install-mcp.command (macOS), then fully quit and reopen Claude Desktop or the ChatGPT desktop app.' }

$fail=@($results | Where-Object { $_.status -eq 'FAIL' }).Count
if ($Json) { [pscustomobject]@{ok=($fail -eq 0);results=$results} | ConvertTo-Json -Depth 5 }
else {
  foreach ($r in $results) {
    $line=('[{0}] {1}: {2}' -f $r.status,$r.step,$r.detail)
    $color='Green'; if ($r.status -eq 'WARN') { $color='Yellow' }; if ($r.status -eq 'FAIL') { $color='Red' }
    Write-Host $line -ForegroundColor $color
    if ($r.fix) { Write-Host ('       fix: ' + $r.fix) }
  }
  if ($fail -eq 0) { Write-Host 'Setup looks good. Ask your AI client: what should this character do next?' }
}
if ($fail -gt 0) { exit 1 }
