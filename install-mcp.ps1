param(
  [switch]$Uninstall,
  [switch]$DryRun,
  [string]$ClaudeConfigPath,
  [string]$CodexConfigPath,
  [string]$ServerName='wow-context'
)
# Registers mcp-server.ps1 (this checkout) with local desktop AI clients on Windows or macOS:
#   Claude Desktop  -> claude_desktop_config.json (mcpServers)
#   Codex / ChatGPT desktop Codex settings -> ~/.codex/config.toml ([mcp_servers.<name>])
# Existing entries are preserved; a timestamped .bak is written before any change.
# Keep this file ASCII-only for Windows PowerShell 5.1.
$ErrorActionPreference='Stop'
try { Remove-TypeData System.Array -ErrorAction Stop } catch { }
. (Join-Path $PSScriptRoot 'lib/common.ps1')
$utf8=New-Object Text.UTF8Encoding($false)
$server=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'mcp-server.ps1'))
if (!(Test-Path -LiteralPath $server)) { throw "mcp-server.ps1 not found next to this script: $server" }
$psExe=Get-PowerShellCommand
$serverArgs=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$server)
$stamp=(Get-Date).ToString('yyyyMMdd-HHmmss')

function Backup($path) {
  if ((Test-Path -LiteralPath $path) -and !$DryRun) { Copy-Item -LiteralPath $path -Destination "$path.$stamp.bak" -Force }
}
function Write-Config($path,[string]$text) {
  if ($DryRun) { Write-Host "[dry run] would write $path"; Write-Host $text; return }
  $dir=Split-Path -Parent $path
  if (!(Test-Path -LiteralPath $dir)) { $null=New-Item -ItemType Directory -Path $dir }
  Backup $path
  [IO.File]::WriteAllText($path,$text,$utf8)
}

# ---------- Claude Desktop ----------
function Find-ClaudeConfig {
  if ($ClaudeConfigPath) { return $ClaudeConfigPath }
  return (Find-ClaudeConfigPath)
}

function Update-Claude($path) {
  $cfg=[pscustomobject]@{}
  if (Test-Path -LiteralPath $path) {
    $raw=[IO.File]::ReadAllText($path,$utf8)
    if ($raw.Trim()) { $cfg=$raw | ConvertFrom-Json }
  }
  if (!$cfg.PSObject.Properties['mcpServers']) { $cfg | Add-Member mcpServers ([pscustomobject]@{}) }
  $servers=$cfg.mcpServers
  if ($Uninstall) {
    if (!$servers.PSObject.Properties[$ServerName]) { Write-Host "Claude Desktop: $ServerName not configured."; return }
    $servers.PSObject.Properties.Remove($ServerName)
  } else {
    $servers | Add-Member $ServerName ([pscustomobject]@{command=$psExe;args=$serverArgs}) -Force
  }
  Write-Config $path ($cfg | ConvertTo-Json -Depth 50)
  Write-Host "Claude Desktop: updated $path"
}

# ---------- Codex (also used by the ChatGPT desktop app's Codex settings) ----------
function Toml-Str([string]$s) { '"' + $s.Replace('\','\\').Replace('"','\"') + '"' }

function Update-Codex($path) {
  $text=''
  if (Test-Path -LiteralPath $path) { $text=[IO.File]::ReadAllText($path,$utf8) }
  $lines=@($text -split "`r?`n")
  if ($text -eq '') { $lines=@() }
  # Drop our existing table (and its sub-tables) so the result has exactly one copy.
  $header='[mcp_servers.' + $ServerName + ']'
  $sub='[mcp_servers.' + $ServerName + '.'
  $kept=@(); $skip=$false; $found=$false
  foreach ($l in $lines) {
    $t=$l.Trim()
    if ($t.StartsWith('[')) {
      $skip=($t -eq $header -or $t.StartsWith($sub))
      if ($skip) { $found=$true }
    }
    if (!$skip) { $kept+=$l }
  }
  while ($kept.Count -gt 0 -and $kept[-1].Trim() -eq '') { $kept=@($kept[0..($kept.Count-2)]) }
  if ($Uninstall -and !$found) { Write-Host "Codex: $ServerName not configured."; return }
  if (!$Uninstall) {
    if ($kept.Count -gt 0) { $kept+='' }
    $kept+=$header
    $kept+=('command = ' + (Toml-Str $psExe))
    $kept+=('args = [' + (($serverArgs | ForEach-Object { Toml-Str $_ }) -join ', ') + ']')
  }
  Write-Config $path ((($kept) -join "`n") + "`n")
  Write-Host "Codex: updated $path"
}

function Find-CodexConfig {
  if ($CodexConfigPath) { return $CodexConfigPath }
  return (Find-CodexConfigPath)
}

Write-Host "MCP server: $server"
$claude=Find-ClaudeConfig
if ($claude) { Update-Claude $claude } else { Write-Host 'Claude Desktop: not found (no config folder). Skipped.' }
Update-Codex (Find-CodexConfig)
if (!$DryRun) {
  Write-Host ''
  Write-Host 'Done. Fully quit and reopen Claude Desktop / ChatGPT desktop / Codex so they load the change.'
  Write-Host 'Keep start.bat (Windows) or start.command (macOS) running so player.json stays current.'
}
