# Installation guide

**English** | [中文](INSTALL.zh-CN.md)

Let an AI desktop client on your PC (Claude Desktop, the ChatGPT desktop app, or Codex) read your WoW Forever character's live state: level, location, quest progress and equipment. Then you can simply ask "What should this character do next?"

The data stays on your own PC. Nothing is uploaded and nothing goes over the network. (When you ask a question, the AI client sends the relevant context to its provider, just like any other chat.)

AI agents installing this for someone: see "Steps for AI agents" below.

## What you need

- A **Windows** PC with the **WoW Forever** client (a `_forever_` folder that contains `Wow.exe`). Verified on 1.60.1.71139, Interface 16001, Simplified Chinese client. The addon only sends data on Interface 16001.
- At least one AI desktop client: Claude Desktop, the ChatGPT desktop app, or Codex. Web versions cannot read local data.
- Nothing else to install: the built-in Windows PowerShell is enough. No Python needed.

## First-time install

1. **Download this repository.** On the GitHub page click Code → Download ZIP and unzip it, or `git clone` it. Put it somewhere permanent, for example `Documents\wow-context-bridge`, and don't move it later: the AI client configuration remembers this path.
2. **Double-click `start.bat`.** It will:
   - find the game folder automatically (if it finds none or several, it tells you; see "Troubleshooting" for `-GameRoot`);
   - copy the `LocalContext` addon into the game's `Interface\AddOns`;
   - start reading data. **Keep this window open.**
3. **Fully quit the game and start it again**, then log in to a character. An addon installed while the game is running only loads after a restart.
4. **Double-click `install-mcp.bat`.** It registers this tool with Claude Desktop and Codex / the ChatGPT desktop app. Your existing settings are kept, and a backup is written before any change.
5. **Fully quit and reopen your AI client** (also quit it from the tray icon).
6. **Double-click `check-setup.bat`** to check each step. When every line says `[PASS]` you are done; each `[FAIL]` shows how to fix it.
7. Ask your AI client: **"What should this character do next?"** The answer should mention how many seconds old the data is.

## Every time you play

Double-click `start.bat` first (keep the window open), then start the game. The AI client needs no further setup. If `start.bat` isn't running, the AI will tell you the reader is not running and the data is old.

## Updating

Download the new version over the old folder (or `git pull`), double-click `start.bat` (this updates the addon), then restart the game. If the folder didn't move, you don't need to run `install-mcp.bat` again.

## Uninstalling

1. In PowerShell, run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install-mcp.ps1 -Uninstall` to remove the tool from your AI client configuration.
2. Delete `Interface\AddOns\LocalContext` in the game folder (or disable it in the in-game addon list).
3. Delete this folder.

## Privacy

- The addon only uses the game's public addon API. It does not read memory, simulate keyboard or mouse input, send chat or use the network.
- To get data out of the game, the addon **turns on the game's chat log** (`Logs\WoWChatLog.txt`). That log also records other chat, **including whispers**. This tool reads only its own data lines and never deletes the file.
- The generated `player.json` and `history.jsonl` contain your character name and location. Don't upload or share them.

## Troubleshooting

Run `check-setup.bat` first; it tells you which step is broken.

| Problem | Fix |
| --- | --- |
| Game folder not found, or several found | Open PowerShell in this folder and run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\start.ps1 -GameRoot 'E:\your\path\World of Warcraft\_forever_'` |
| The AI says there is no character data | Make sure you restarted the game and logged in, `start.bat` is open, and wait about 20 seconds |
| The AI says the data is minutes old | Normal during combat, loading screens or when logged out; otherwise check the "game log" step of `check-setup.bat` |
| wow-context doesn't appear in the AI client | Run `install-mcp.bat` again, then **fully** quit and reopen the client |
| You moved the folder | Run `install-mcp.bat` again |

## Steps for AI agents

For AI agents (Codex, Claude Code, ...) installing this for a user. Run commands from the repository root.

1. Confirm this is Windows, then find the game folder: run `check-setup.ps1 -Json` (run every `.ps1` below as `powershell.exe -NoProfile -ExecutionPolicy Bypass -File <script>`) and read the `game folder` entry. If several folders are found, **ask the user which one**; never guess.
2. Run `start.ps1` (add `-GameRoot` if needed). It installs the addon and keeps running. Run it in the background or a separate window, and record the exact command line. Never stop a process just because an old PID file matches it.
3. If the game is already running, **ask the user** to restart it and log in. Never operate the game for the user or send it any input.
4. Run `install-mcp.ps1` (add `-DryRun` to preview). It changes only the `wow-context` entry and writes a backup first.
5. Ask the user to fully quit and reopen their AI client.
6. Run `check-setup.ps1 -Json` again until `ok=true`. Apply each entry's `fix`, and tell the user about steps only they can do.
7. For gameplay questions, follow `docs/ADVISOR.md`.
8. Never commit or upload `player.json`, `history.jsonl` or the game chat log, and never delete the chat log. Development rules are in `AGENTS.md`.
