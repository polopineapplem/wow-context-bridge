# WoW Forever Context Bridge

**English** | [中文](README.zh-CN.md)

Let the AI on your PC see your WoW Forever character, then ask it things like **"What should this character do next?"**

A small in-game addon and a local reader keep an up-to-date snapshot of your character: level, zone, coordinates, quest progress and equipment. A read-only local [MCP](https://modelcontextprotocol.io) server lets desktop AI clients (Claude Desktop, the ChatGPT desktop app, Codex) read it. Everything runs on your own PC: no cloud, no account, no network.

```
WoW Forever ─▶ LocalContext addon ─▶ game chat log ─▶ start.bat reader ─▶ player.json + history.jsonl
                                                                                   │
                                     Claude Desktop / ChatGPT desktop / Codex ◀─ mcp-server.ps1 (local, read-only)
```

## Install

**Full guide: [INSTALL.md](INSTALL.md)**. It covers you, your friends, and AI agents installing it for someone. In short:

1. Download this repository to a permanent folder.
2. Double-click `start.bat`. It finds the game, installs the addon and starts reading. Keep the window open.
3. Fully restart the game and log in.
4. Double-click `install-mcp.bat`, then fully reopen your AI client.
5. Double-click `check-setup.bat` to verify every step.
6. Ask: "What should this character do next?"

Requirements: Windows and the WoW Forever client. Verified on 1.60.1.71139, Interface 16001, zhCN. Nothing to install besides the built-in Windows PowerShell.

## What the AI can see

- Character: name, class, race, level.
- Active quests: ID, name, objective text, counts (e.g. 9/20), complete state.
- Completed quest IDs (when the game API provides them).
- Map, zone, subzone and coordinates (percent of map).
- Equipped items in slots 1–19 (ID and name).
- Recent changes: level ups, zone changes, quest progress, gear swaps.
- Freshness: how old the snapshot is, and whether the reader is still running.

MCP tools: `get_player_context`, `get_quests`, `get_equipment`, `get_recent_changes`, plus a `what_next` prompt that follows the advisor rules in [docs/ADVISOR.md](docs/ADVISOR.md).

## Supported AI clients

| Client | How |
| --- | --- |
| Claude Desktop | `install-mcp.bat` configures it (including the Microsoft Store version) |
| Codex / ChatGPT desktop app | `install-mcp.bat` writes `~/.codex/config.toml`; the ChatGPT desktop app's Codex settings use the same file (reported by third parties, not yet verified by us) |
| Claude Code | `claude mcp add wow-context -- powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\path\to\wow-context-bridge\mcp-server.ps1` |
| Web or mobile chat | Not supported: they cannot reach files on your PC |

The AI client must run on the same Windows PC as the game. Keep `start.bat` running; the MCP server only reads files and collects nothing itself.

<details>
<summary>Manual configuration</summary>

Replace the path with this folder's real location.

Claude Desktop (`%APPDATA%\Claude\claude_desktop_config.json`):

```json
{"mcpServers":{"wow-context":{"command":"powershell.exe","args":["-NoProfile","-ExecutionPolicy","Bypass","-File","C:\\path\\to\\wow-context-bridge\\mcp-server.ps1"]}}}
```

Codex (`~/.codex/config.toml`):

```toml
[mcp_servers.wow-context]
command = "powershell.exe"
args = ["-NoProfile","-ExecutionPolicy","Bypass","-File","C:\\path\\to\\wow-context-bridge\\mcp-server.ps1"]
```

</details>

## Privacy and safety

- The addon only uses the game's public addon API. It does not read game memory, simulate input, send chat, open ports or contact any server.
- **The addon turns on the game's chat log, which also records whispers and other chat.** The reader extracts only its own `LCB1` lines and never deletes the log. The log grows by roughly 12 MB per hour of play.
- `player.json` and `history.jsonl` contain your character name and location. They are git-ignored; don't share them.
- Text from the game (quest names, item names) is passed to the AI as data, and the AI is told not to follow it as instructions.

## Limits

- Snapshots every 15 seconds, paused in combat. Data older than 60 seconds is marked stale.
- Quests under collapsed quest-log headers may be missing; the data says so (`questLogMayBeIncomplete`).
- Only Interface 16001 is supported. Other clients, versions and locales are untested.
- The advisor knows little about Forever-specific quest locations; it is told to say when it isn't sure instead of inventing them.

## Development

- Start with [HANDOFF.md](HANDOFF.md), [docs/TASKS.md](docs/TASKS.md) and [docs/START_HERE.md](docs/START_HERE.md). Rules for AI coding agents are in [AGENTS.md](AGENTS.md) (Claude Code reads it via `CLAUDE.md`). Developer docs in `docs/` are in Chinese.
- Tests (mock data only, not a live game test):
  - `pwsh -File test-reader.ps1`: log reader.
  - `python tests/test_mcp.py`: MCP server.
  - `python tests/test_install_mcp.py`: client setup.
  - `python tests/test_check_setup.py`: setup checker.
  - `python tests/test_addon.py`: addon, run in Lua 5.1; needs `pip install lupa==2.8`.

  Set `PWSH` to point the Python tests at a specific PowerShell. `test-reader.ps1` contains Chinese text: on Windows PowerShell 5.1, save it as UTF-8 with BOM first, or use PowerShell 7.

## License and disclaimer

[MIT](LICENSE). This is an independent fan project, not affiliated with or endorsed by Blizzard Entertainment. World of Warcraft is a trademark of Blizzard Entertainment. Use addons according to the game's terms and addon policy.
