# Shared helpers, dot-sourced by start.ps1, install-mcp.ps1 and check-setup.ps1.
# Keep this file ASCII-only for Windows PowerShell 5.1.

function Test-ForeverRoot([string]$path) {
  if (!$path) { return $false }
  try { return (Test-Path -LiteralPath (Join-Path $path 'Wow.exe')) } catch { return $false }
}

# Returns every distinct "_forever_" client folder that contains Wow.exe.
# $ExtraRoots: additional "World of Warcraft" (or "_forever_") folders to check, used by tests.
function Find-ForeverRoots([string[]]$ExtraRoots=@()) {
  $bases=New-Object Collections.Generic.List[string]
  foreach ($r in $ExtraRoots) { if ($r) { $bases.Add($r) } }
  $regKeys=@(
    'HKLM:\SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft',
    'HKLM:\SOFTWARE\Blizzard Entertainment\World of Warcraft',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\World of Warcraft',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\World of Warcraft'
  )
  foreach ($k in $regKeys) {
    try {
      $p=Get-ItemProperty -LiteralPath $k -ErrorAction Stop
      foreach ($name in 'InstallPath','InstallLocation') {
        $v=$p.$name
        if ($v) { $bases.Add($v.TrimEnd('\')); $bases.Add((Split-Path -Parent $v.TrimEnd('\'))) }
      }
    } catch { }
  }
  if ($env:OS -eq 'Windows_NT') {
    foreach ($d in [IO.DriveInfo]::GetDrives()) {
      try { if ($d.DriveType -ne 'Fixed' -or !$d.IsReady) { continue } } catch { continue }
      $root=$d.RootDirectory.FullName
      foreach ($rel in 'World of Warcraft','Program Files (x86)\World of Warcraft','Program Files\World of Warcraft','Games\World of Warcraft','Battle.net\World of Warcraft','Blizzard\World of Warcraft') {
        $bases.Add((Join-Path $root $rel))
      }
    }
  }
  $found=New-Object Collections.Generic.List[string]
  $seen=@{}
  foreach ($b in $bases) {
    foreach ($c in @($b,(Join-Path $b '_forever_'))) {
      if ((Split-Path -Leaf $c) -ne '_forever_') { continue }
      if (!(Test-ForeverRoot $c)) { continue }
      $full=[IO.Path]::GetFullPath($c).TrimEnd('\','/')
      $key=$full.ToLowerInvariant()
      if (!$seen.ContainsKey($key)) { $seen[$key]=$true; $found.Add($full) }
    }
  }
  return ,($found.ToArray())
}

# Resolve the game folder: explicit value wins, otherwise exactly one detected folder.
function Resolve-ForeverRoot([string]$GameRoot,[string[]]$ExtraRoots=@()) {
  if ($GameRoot) {
    if (!(Test-ForeverRoot $GameRoot)) { throw "Wow.exe not found in -GameRoot '$GameRoot'. Pass the _forever_ folder that contains Wow.exe." }
    return $GameRoot
  }
  # Find-ForeverRoots returns the array as one object; assign first so @() does not nest it.
  $found=Find-ForeverRoots $ExtraRoots
  $found=@($found)
  if ($found.Count -eq 1) { return $found[0] }
  if ($found.Count -eq 0) { throw "WoW Forever not found automatically. Run again with -GameRoot 'X:\path\World of Warcraft\_forever_' (the folder that contains Wow.exe)." }
  throw ("Several WoW Forever folders found; choose one with -GameRoot:`n  " + ($found -join "`n  "))
}

function Find-ClaudeConfigPath {
  $candidates=@()
  if ($env:LOCALAPPDATA) {
    # Microsoft Store (MSIX) install keeps its roaming data inside the package.
    $pkgs=Join-Path $env:LOCALAPPDATA 'Packages'
    if (Test-Path -LiteralPath $pkgs) {
      foreach ($d in Get-ChildItem -LiteralPath $pkgs -Directory -Filter 'Claude_*' -ErrorAction SilentlyContinue) {
        $candidates+=(Join-Path $d.FullName 'LocalCache\Roaming\Claude\claude_desktop_config.json')
      }
    }
  }
  if ($env:APPDATA) { $candidates+=(Join-Path $env:APPDATA 'Claude\claude_desktop_config.json') }
  foreach ($c in $candidates) { if (Test-Path -LiteralPath (Split-Path -Parent $c)) { return $c } }
  return $null
}

function Find-CodexConfigPath {
  $h=$env:CODEX_HOME
  if (!$h) {
    $userHome=$env:USERPROFILE; if (!$userHome) { $userHome=$env:HOME }
    $h=Join-Path $userHome '.codex'
  }
  return (Join-Path $h 'config.toml')
}
