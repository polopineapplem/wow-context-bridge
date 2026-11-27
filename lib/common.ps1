# Shared helpers, dot-sourced by start.ps1, install-mcp.ps1 and check-setup.ps1.
# Keep this file ASCII-only for Windows PowerShell 5.1.

function Test-IsWindows { return ($env:OS -eq 'Windows_NT') }
function Test-IsMac { return ((Get-Variable -Name IsMacOS -ValueOnly -ErrorAction SilentlyContinue) -eq $true) }

# A Forever client folder holds Wow.exe (Windows) or World of Warcraft.app (macOS).
function Test-ForeverRoot([string]$path) {
  if (!$path) { return $false }
  try {
    return ((Test-Path -LiteralPath (Join-Path $path 'Wow.exe')) -or (Test-Path -LiteralPath (Join-Path $path 'World of Warcraft.app')))
  } catch { return $false }
}

# Command that AI clients should use to start our scripts.
function Get-PowerShellCommand {
  if (Test-IsWindows) {
    if ($env:SystemRoot) {
      $full=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
      if (Test-Path -LiteralPath $full) { return $full }
    }
    return 'powershell.exe'
  }
  # macOS/Linux: the pwsh running this script (resolve symlinks so the path stays valid).
  $p=(Get-Process -Id $PID).Path
  try { $t=(Get-Item -LiteralPath $p).ResolvedTarget; if ($t) { $p=[string]$t } } catch { }
  return $p
}

# Returns every distinct "_forever_" client folder that contains Wow.exe.
# $ExtraRoots: additional "World of Warcraft" (or "_forever_") folders to check, used by tests.
function Find-ForeverRoots([string[]]$ExtraRoots=@()) {
  $bases=New-Object Collections.Generic.List[string]
  foreach ($r in $ExtraRoots) { if ($r) { $bases.Add($r) } }
  # Tests set WOW_CONTEXT_NO_SYSTEM_SEARCH=1 so results don't depend on what this machine has installed.
  $system=($env:WOW_CONTEXT_NO_SYSTEM_SEARCH -ne '1')
  $regKeys=@()
  if ($system) { $regKeys=@(
    'HKLM:\SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft',
    'HKLM:\SOFTWARE\Blizzard Entertainment\World of Warcraft',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\World of Warcraft',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\World of Warcraft'
  ) }
  foreach ($k in $regKeys) {
    try {
      $p=Get-ItemProperty -LiteralPath $k -ErrorAction Stop
      foreach ($name in 'InstallPath','InstallLocation') {
        $v=$p.$name
        if ($v) { $bases.Add($v.TrimEnd('\')); $bases.Add((Split-Path -Parent $v.TrimEnd('\'))) }
      }
    } catch { }
  }
  if ($system -and (Test-IsMac)) {
    $bases.Add('/Applications/World of Warcraft')
    if ($env:HOME) { $bases.Add((Join-Path $env:HOME 'Applications/World of Warcraft')) }
  }
  if ($system -and (Test-IsWindows)) {
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
    if (!(Test-ForeverRoot $GameRoot)) { throw "No Forever client in -GameRoot '$GameRoot'. Pass the _forever_ folder (it contains Wow.exe on Windows or World of Warcraft.app on macOS)." }
    return $GameRoot
  }
  # Find-ForeverRoots returns the array as one object; assign first so @() does not nest it.
  $found=Find-ForeverRoots $ExtraRoots
  $found=@($found)
  if ($found.Count -eq 1) { return $found[0] }
  if ($found.Count -eq 0) { throw "WoW Forever not found automatically. Run again with -GameRoot set to the _forever_ folder (contains Wow.exe on Windows or World of Warcraft.app on macOS)." }
  throw ("Several WoW Forever folders found; choose one with -GameRoot:`n  " + ($found -join "`n  "))
}

function Find-ClaudeConfigPath {
  $candidates=@()
  if ((Test-IsMac) -and $env:HOME) { $candidates+=(Join-Path $env:HOME 'Library/Application Support/Claude/claude_desktop_config.json') }
  if ($env:LOCALAPPDATA) {
    # Microsoft Store (MSIX) install keeps its roaming data inside the package.
    $pkgs=Join-Path $env:LOCALAPPDATA 'Packages'
    if (Test-Path -LiteralPath $pkgs) {
      foreach ($d in Get-ChildItem -LiteralPath $pkgs -Directory -Filter 'Claude_*' -ErrorAction SilentlyContinue) {
        $candidates+=(Join-Path $d.FullName 'LocalCache/Roaming/Claude/claude_desktop_config.json')
      }
    }
  }
  if ($env:APPDATA) { $candidates+=(Join-Path $env:APPDATA 'Claude/claude_desktop_config.json') }
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

# macOS privacy (TCC): Claude Desktop and other apps start MCP servers that cannot read
# ~/Documents, ~/Desktop, ~/Downloads or iCloud Drive unless the app has been granted access,
# and even then access did not work in testing (2026-11-27, see docs/DECISIONS.md D18).
# So when the checkout lives there, keep runtime files in ~/Library/Application Support instead.
function Test-MacProtectedPath([string]$path,[string]$userHome=$env:HOME) {
  if (!$path -or !$userHome) { return $false }
  $p=[IO.Path]::GetFullPath($path).TrimEnd('/') + '/'
  foreach ($rel in 'Documents','Desktop','Downloads','Library/Mobile Documents') {
    $prefix=(Join-Path $userHome $rel).TrimEnd('/') + '/'
    if ($p.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) { return $true }
  }
  return $false
}

# Folder for player.json, history.jsonl and the copy of mcp-server.ps1 that AI clients run.
# WOW_CONTEXT_RUNTIME_DIR overrides it (used by tests).
function Get-RuntimeDir([string]$checkout) {
  if ($env:WOW_CONTEXT_RUNTIME_DIR) { return $env:WOW_CONTEXT_RUNTIME_DIR }
  if ((Test-IsMac) -and (Test-MacProtectedPath $checkout)) { return (Join-Path $env:HOME 'Library/Application Support/wow-context-bridge') }
  return $checkout
}

# Returns the mcp-server.ps1 path AI clients should run. Outside the checkout it is a copy,
# refreshed here (with docs/ADVISOR.md for the what_next prompt) unless -NoCopy.
function Sync-McpServer([string]$checkout,[switch]$NoCopy) {
  $dir=Get-RuntimeDir $checkout
  $src=[IO.Path]::GetFullPath((Join-Path $checkout 'mcp-server.ps1'))
  $dst=[IO.Path]::GetFullPath((Join-Path $dir 'mcp-server.ps1'))
  if ($dst -eq $src -or $NoCopy) { return $dst }
  $docs=Join-Path $dir 'docs'
  if (!(Test-Path -LiteralPath $docs)) { $null=New-Item -ItemType Directory -Path $docs -Force }
  Copy-Item -LiteralPath $src -Destination $dst -Force
  Copy-Item -LiteralPath (Join-Path $checkout 'docs/ADVISOR.md') -Destination (Join-Path $docs 'ADVISOR.md') -Force
  return $dst
}

# Meaningful state of a snapshot: used by history.jsonl (start.ps1, D9) and the remote push policy (lib/remote.ps1, D22).
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
