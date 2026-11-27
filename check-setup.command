#!/bin/bash
# macOS launcher: double-click in Finder. Needs PowerShell 7 (pwsh); see INSTALL.md.
cd "$(dirname "$0")" || exit 1
PWSH="$(command -v pwsh)"
for c in /usr/local/bin/pwsh /opt/homebrew/bin/pwsh "$HOME/.local/bin/pwsh" /usr/local/microsoft/powershell/7/pwsh; do
  [ -z "$PWSH" ] && [ -x "$c" ] && PWSH="$c"
done
if [ -z "$PWSH" ]; then
  echo "PowerShell 7 (pwsh) not found. Install it first:  brew install --cask powershell"
  echo "or see https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-macos"
  read -r -p "Press Enter to close." _; exit 1
fi
"$PWSH" -NoProfile -File ./check-setup.ps1 "$@"
status=$?
read -r -p "Press Enter to close." _
exit $status
