# Installation guide

**English** | [中文](INSTALL.zh-CN.md)

Let an AI desktop client on your PC (Claude Desktop, the ChatGPT desktop app, or Codex) read your WoW Forever character's live state: level, location, quest progress and equipment. Then you can simply ask "What should this character do next?"

The data stays on your own PC. Nothing is uploaded and nothing goes over the network. (When you ask a question, the AI client sends the relevant context to its provider, just like any other chat.)

AI agents installing this for someone: see "Steps for AI agents" below.

## What you need

- A **Windows** PC or a **Mac** with the **WoW Forever** client (a `_forever_` folder containing `Wow.exe` on Windows, or `World of Warcraft.app` on macOS). Verified on 1.60.1.71139, Interface 16001, Simplified Chinese client. The addon only sends data on Interface 16001.
- At least one AI desktop client: Claude Desktop, the ChatGPT desktop app, or Codex. Web versions cannot read local data.
- **Windows:** nothing else to install; the built-in Windows PowerShell is enough.
- **macOS:** install PowerShell 7 once: `brew install --cask powershell` (or Microsoft's installer). No Python needed.

Each step below names the Windows file (`.bat`) and the Mac file (`.command`); double-click the one for your system. On a Mac the first double-click may be blocked by Gatekeeper; then right-click the file → Open.

## First-time install

1. **Download this repository.** On the GitHub page click Code → Download ZIP and unzip it, or `git clone` it. Put it somewhere permanent, for example `Documents\wow-context-bridge`, and don't move it later: the AI client configuration remembers this path.
2. **Double-click `start.bat`** (Windows) **or `start.command`** (macOS). It will:
   - find the game folder automatically (if it finds none or several, it tells you; see "Troubleshooting" for `-GameRoot`);
   - copy the `LocalContext` addon into the game's `Interface\AddOns`;
   - start reading data. **Keep this window open.**
3. **Fully quit the game and start it again**, then log in to a character. An addon installed while the game is running only loads after a restart.
4. **Double-click `install-mcp.bat` / `install-mcp.command`.** It registers this tool with Claude Desktop and Codex / the ChatGPT desktop app. Your existing settings are kept, and a backup is written before any change.
5. **Fully quit and reopen your AI client** (also quit it from the tray icon).
6. **Double-click `check-setup.bat` / `check-setup.command`** to check each step. When every line says `[PASS]` you are done; each `[FAIL]` shows how to fix it.
7. Ask your AI client: **"What should this character do next?"** The answer should mention how many seconds old the data is.

## Every time you play

Double-click `start.bat` / `start.command` first (keep the window open), then start the game. The AI client needs no further setup. If `start.bat` isn't running, the AI will tell you the reader is not running and the data is old.

## Updating

Download the new version over the old folder (or `git pull`), double-click `start.bat` (this updates the addon), then restart the game. If the folder didn't move, you don't need to run `install-mcp.bat` again.

## Optional: Claude on the web and phone (remote upload)

Everything above stays on your PC. Claude on the web (claude.ai) and in the phone apps runs in Anthropic's cloud and cannot read your PC, so this optional step sends your snapshot to a small server **you** own on Cloudflare's free plan. Claude then reads it from there with the same read-only tools. It is off unless you set it up.

**ChatGPT:** the ChatGPT website and apps can't use it on the Plus plan. As of November 2026, OpenAI lists custom MCP servers only for Business, Enterprise and Edu (Pro is read-only), and only with OAuth or no sign-in, which this server doesn't offer. Details: [docs/REMOTE_MCP.md](docs/REMOTE_MCP.md). On the game PC, ChatGPT's desktop app can still use the local setup above.

What you need: a free [Cloudflare](https://dash.cloudflare.com/sign-up) account and [Node.js](https://nodejs.org) LTS on the game PC.

1. **Deploy the server** (once). In a terminal, from this folder:
   ```
   cd remote
   npx wrangler@4 login
   npm run deploy
   ```
   `login` opens your browser to sign in to Cloudflare. `deploy` prints your server address, like `https://wow-context-bridge.<your-name>.workers.dev`.
2. **Connect the reader.** Back in this folder, double-click `configure-remote.bat` (Windows) or `configure-remote.command` (macOS) and paste the address. It creates two random keys (one for uploading, one for reading) and saves them in your user folder, **not** in this repository:
   - Windows: `%APPDATA%\wow-context-bridge\remote.json`
   - macOS: `~/Library/Application Support/wow-context-bridge/remote.json`
3. **Store the keys on the server and test it:**
   - Windows: `configure-remote.bat -SetSecrets -Check`
   - macOS: `./configure-remote.command -SetSecrets -Check`

   Both lines should say `PASS`. Right after the first deploy, `FAIL ... SSL connection could not be established` is normal: the new `workers.dev` address needs a few minutes (about 2 in testing) before HTTPS works. Wait, then run it again with only `-Check`.
4. **Restart `start.bat` / `start.command`.** It should say `Remote upload ON`. It sends a snapshot when your level, zone, quests or gear change, or you move more than 3% of the map. It sends at most once every 30 seconds, plus a heartbeat every 3 minutes.
5. **Add the connector in Claude** (claude.ai, Customize, Connectors, then **+ Add** and **Add custom connector**). Use the settings that `configure-remote` printed. Run it again with `-ShowConnector` to see them again.
   - Authentication: **No sign-in**.
   - If the dialog has a **Request headers** section: set the URL to `https://…workers.dev/mcp` and add an `authorization` header with the value `Bearer <read key>`.
   - Otherwise set the URL to `https://…workers.dev/mcp/<read key>`.
6. Ask Claude: "What should this character do next?" Data older than 4 minutes is marked stale.

**What is uploaded:** the same data as `player.json`, plus your last 50 recorded changes. Never the chat log. Anyone who has the read key, or the URL that contains it, can read your character, so keep both private. If one leaks, run `configure-remote -NewTokens -SetSecrets` and add the connector again.

**Turning it off:** `configure-remote.bat -Disable` (or `./configure-remote.command -Disable`), then restart the reader. To delete the server and its data, run `npx wrangler@4 delete` in the `remote` folder.

**Cost:** the free plan allows 100,000 requests a day. This tool sends at most about 2,900 uploads a day, so it stays free.

## Uninstalling

1. Run `install-mcp.ps1 -Uninstall` (Windows: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install-mcp.ps1 -Uninstall`; macOS: `pwsh -NoProfile -File ./install-mcp.ps1 -Uninstall`) to remove the tool from your AI client configuration.
2. Delete `Interface\AddOns\LocalContext` in the game folder (or disable it in the in-game addon list).
3. Delete this folder.

## Privacy

- The addon only uses the game's public addon API. It does not read memory, simulate keyboard or mouse input, send chat or use the network.
- To get data out of the game, the addon **turns on the game's chat log** (`Logs\WoWChatLog.txt`). That log also records other chat, **including whispers**. This tool reads only its own data lines and never deletes the file.
- The generated `player.json` and `history.jsonl` contain your character name and location. Don't upload or share them.
- **Mac, folder in Documents, Desktop, Downloads or iCloud Drive:** macOS doesn't let AI apps read those folders. In that case `player.json`, `history.jsonl` and a copy of the MCP server go to `~/Library/Application Support/wow-context-bridge` instead. `start.command` and `install-mcp.command` handle this automatically.

## Troubleshooting

Run `check-setup.bat` first; it tells you which step is broken.

| Problem | Fix |
| --- | --- |
| Game folder not found, or several found | Windows: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\start.ps1 -GameRoot 'E:\your\path\World of Warcraft\_forever_'`. macOS: `pwsh -NoProfile -File ./start.ps1 -GameRoot '/Applications/World of Warcraft/_forever_'` |
| Mac: "pwsh not found" | `brew install --cask powershell`, then double-click again |
| The AI says there is no character data | Make sure you restarted the game and logged in, `start.bat` is open, and wait about 20 seconds |
| The AI says the data is minutes old | Normal during combat, loading screens or when logged out; otherwise check the "game log" step of `check-setup.bat` |
| wow-context doesn't appear in the AI client | Run `install-mcp.bat` again, then **fully** quit and reopen the client |
| Mac: Claude's log `~/Library/Logs/Claude/mcp-server-wow-context.log` says "Access to the path … is denied" | The folder is in Documents/Desktop/Downloads/iCloud. Update to the latest version, run `install-mcp.command`, restart `start.command`, then fully quit (Cmd+Q) and reopen Claude |
| You moved the folder | Run `install-mcp.bat` again |

## Steps for AI agents

For AI agents (Codex, Claude Code, ...) installing this for a user. Run commands from the repository root.

1. Find the game folder: run `check-setup.ps1 -Json` (run every `.ps1` below as `powershell.exe -NoProfile -ExecutionPolicy Bypass -File <script>` on Windows, or `pwsh -NoProfile -File <script>` on macOS; install PowerShell 7 on a Mac first, telling the user) and read the `game folder` entry. If several folders are found, **ask the user which one**; never guess.
2. Run `start.ps1` (add `-GameRoot` if needed). It installs the addon and keeps running. Run it in the background or a separate window, and record the exact command line. Never stop a process just because an old PID file matches it.
3. If the game is already running, **ask the user** to restart it and log in. Never operate the game for the user or send it any input.
4. Run `install-mcp.ps1` (add `-DryRun` to preview). It changes only the `wow-context` entry and writes a backup first.
5. Ask the user to fully quit and reopen their AI client.
6. Run `check-setup.ps1 -Json` again until `ok=true`. Apply each entry's `fix`, and tell the user about steps only they can do.
7. For gameplay questions, follow `docs/ADVISOR.md`.
8. Remote upload ("Optional: Claude on the web and phone") is only for users who ask for it. Signing in to Cloudflare, deploying and adding the Claude connector are the user's steps: give them the exact commands. Never print or commit their keys or server address to a shared place.
9. Never commit or share `player.json`, `history.jsonl` or the game chat log (the user's own opt-in remote upload is the only exception, and it never sends the chat log), and never delete the chat log. Development rules are in `AGENTS.md`.
