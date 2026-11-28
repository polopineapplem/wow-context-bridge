# WoW Forever Context Bridge

[English](README.md) | **中文**

让你电脑上的 AI 看到你的 WoW Forever 角色，然后直接问它：**“这个角色下一步做什么？”**

游戏内的小插件和本地读取器会持续更新角色快照：等级、区域、坐标、任务进度和装备。桌面 AI 客户端（Claude Desktop、ChatGPT 桌面客户端、Codex）通过本地只读的 [MCP](https://modelcontextprotocol.io) 服务器读取这些数据。全部在你自己的电脑上运行：不上云、不用注册账号、不联网。另有默认关闭的可选远程上传，经由你自己在 Cloudflare 免费方案上的小服务器，让网页版和手机上的 Claude 也能读取。

```
WoW Forever ─▶ LocalContext 插件 ─▶ 游戏聊天日志 ─▶ start.bat 读取器 ─▶ player.json + history.jsonl
                                                                                   │
                                     Claude Desktop / ChatGPT 桌面客户端 / Codex ◀─ mcp-server.ps1（本地、只读）
```

## 安装

**完整步骤见 [INSTALL.zh-CN.md](INSTALL.zh-CN.md)**，自己安装、朋友安装、请 AI 助手帮忙安装都适用。简要流程：

1. 下载本仓库，放到固定位置。
2. 双击 `start.bat`（Windows）或 `start.command`（macOS）：自动找到游戏、安装插件、开始读取。窗口保持开着。
3. 完全重启游戏并登录角色。
4. 双击 `install-mcp.bat` / `install-mcp.command`，然后完全重开 AI 客户端。
5. 双击 `check-setup.bat` / `check-setup.command`，逐项检查。
6. 问 AI：“这个角色下一步做什么？”

需要：Windows 或 macOS，以及 WoW Forever 客户端（已验证版本：1.60.1.71139、Interface 16001、zhCN）。Windows 不需要再装任何东西；macOS 需要 PowerShell 7（`brew install --cask powershell`）。

## AI 能看到什么

- 角色：姓名、职业、种族、等级。
- 当前任务：ID、名称、目标文本、数量（如 9/20）、是否完成。
- 已完成任务 ID（游戏 API 提供时）。
- 地图、区域、子区域、坐标（地图百分比）。
- 装备槽 1–19 的物品 ID 和名称。
- 最近变化：升级、换区域、任务进度、换装备。
- 新鲜度：快照是多久以前的、读取器是否还在运行。

MCP 工具：`get_player_context`、`get_quests`、`get_equipment`、`get_recent_changes`、`get_game_profile`；另有 `what_next` 提示，遵循 [docs/ADVISOR.md](docs/ADVISOR.md) 的顾问规则。

WoW Forever（魔兽世界：无限）是独立的产品线，不是经典怀旧服，也不是正式服。[`config/game-profile.json`](config/game-profile.json) 是针对客户端 1.60.1（Interface 16001）整理的静态版本资料：带来源和置信度的事实、与经典怀旧服和正式服的区别、可信攻略来源和顾问规则。顾问按它回答；实时客户端版本与资料不一致时，服务器会给出警告。运行时不联网。Forever 更新后如何修改见 [docs/GAME_PROFILE.md](docs/GAME_PROFILE.md)。

## 支持的 AI 客户端

| 客户端 | 方式 |
| --- | --- |
| Claude Desktop | `install-mcp` 在 Windows（包括 Microsoft Store 版）和 macOS 上自动配置 |
| Codex / ChatGPT 桌面客户端 | `install-mcp` 写入 `~/.codex/config.toml`；据第三方资料，ChatGPT 桌面客户端的 Codex 设置使用同一份文件（我们尚未实测） |
| Claude Code | `claude mcp add wow-context -- powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\path\to\wow-context-bridge\mcp-server.ps1` |
| 网页版 Claude（claude.ai）和手机 App | 可选：远程上传到你自己的免费 Cloudflare 服务器，再添加自定义连接器，见 [INSTALL.zh-CN.md](INSTALL.zh-CN.md#可选网页版和手机上的-claude远程上传) |
| ChatGPT 网页和 App | Plus 用不了：OpenAI 只给 Business/Enterprise/Edu 开放自定义 MCP（Pro 只读），且只支持 OAuth，本项目不提供（[详情](docs/REMOTE_MCP.md)） |

除可选的远程上传外，AI 客户端必须和游戏在同一台电脑上。`start.bat` / `start.command` 要保持运行；MCP 服务器只读文件，本身不采集数据。

<details>
<summary>手动配置</summary>

把路径换成本文件夹的实际位置。macOS 上 command 用 `pwsh` 的完整路径，并去掉 `-ExecutionPolicy Bypass`。

Claude Desktop（Windows：`%APPDATA%\Claude\claude_desktop_config.json`；macOS：`~/Library/Application Support/Claude/claude_desktop_config.json`）：

```json
{"mcpServers":{"wow-context":{"command":"powershell.exe","args":["-NoProfile","-ExecutionPolicy","Bypass","-File","C:\\path\\to\\wow-context-bridge\\mcp-server.ps1"]}}}
```

Codex（`~/.codex/config.toml`）：

```toml
[mcp_servers.wow-context]
command = "powershell.exe"
args = ["-NoProfile","-ExecutionPolicy","Bypass","-File","C:\\path\\to\\wow-context-bridge\\mcp-server.ps1"]
```

</details>

## 隐私与安全

- 插件只使用游戏公开的插件 API。不读游戏内存、不模拟输入、不发聊天、不开端口、不连接任何服务器。
- **插件会开启游戏的聊天记录，记录里也有私聊和其他聊天内容。** 读取器只提取自己的 `LCB1` 数据行，不会删除这份记录。玩一小时，日志大约增加 12 MB。
- `player.json` 和 `history.jsonl` 包含角色名和位置，已被 git 忽略，请不要分享。
- 远程上传默认关闭，只有运行 `configure-remote` 后才开启。开启后把快照和最近变化（从不包括聊天记录）发到你自己的 Cloudflare Worker，用保存在仓库外的随机密钥保护。拿到读取密钥的人都能读取角色。
- 游戏里的文字（任务名、物品名）作为数据交给 AI，AI 被要求不要把它们当成指令执行。

## 限制

- 每 15 秒一次快照，战斗中暂停；超过 60 秒的数据会被标记为过期。
- 任务日志里折叠分类下的任务可能读不到，数据中会用 `questLogMayBeIncomplete` 标明。
- 只支持 Interface 16001。其他客户端、版本和语言未测试。1.60.1.71139 的 Windows 版和 macOS 版都支持。
- 顾问对 Forever 特有的任务位置了解有限，不确定时它被要求直说，而不是编造。

## 开发

- 从 [HANDOFF.md](HANDOFF.md)、[docs/TASKS.md](docs/TASKS.md) 和 [docs/START_HERE.md](docs/START_HERE.md) 开始。AI 编程助手的规则在 [AGENTS.md](AGENTS.md)（Claude Code 通过 `CLAUDE.md` 读取）。`docs/` 下的开发文档是中文。
- 测试（均为模拟数据，不等于实机测试）：
  - `pwsh -File test-reader.ps1`：读取器。
  - `python tests/test_mcp.py`：MCP 服务器。
  - `python tests/test_install_mcp.py`：客户端配置。
  - `python tests/test_check_setup.py`：安装检查。
  - `python tests/test_addon.py`：在 Lua 5.1 中运行插件；需要 `pip install lupa==2.8`。
  - `pwsh -File tests/test-remote-push.ps1`：远程上传策略和配置。
  - `node --test remote/test/*.test.mjs`：远程 Worker（内存版 Durable Object，不是 Cloudflare 运行时），以及读取器到 Worker 的端到端测试；需要 Node.js 20 以上。

  可以用 `PWSH` 环境变量指定 Python 测试使用哪个 PowerShell。`test-reader.ps1` 含中文：在 Windows PowerShell 5.1 上要先另存为带 BOM 的 UTF-8，或者改用 PowerShell 7。

## 许可与声明

[MIT](LICENSE)。这是独立的玩家项目，与暴雪娱乐无关，也未获其认可。World of Warcraft（魔兽世界）是暴雪娱乐的商标。请按游戏条款和插件政策使用插件。
