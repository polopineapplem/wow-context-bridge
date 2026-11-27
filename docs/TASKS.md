# 任务看板

最后更新：2026-11-27。取代原 `ROADMAP.md`。状态：`todo` / `doing` / `done` / `blocked`。每次会话结束按 AGENTS.md 的规则更新本文件。

MVP 目标（2026-11-27 用户确认）：任意 AI（ChatGPT 优先，Claude/Codex 也可）能读取**最新**的角色信息，并回答“这个角色下一步做什么”。轻量、本地存储优先，之后再扩展。

## 当前 MVP

| ID | 任务 | 状态 | 验收条件 |
| --- | --- | --- | --- |
| T1 | 读者启动不再重放全部历史 | done（模拟） | 大日志启动时直接得到最后一个完整快照；覆盖半行、分段截断、日志缩短/替换、会话变化、无有效快照；历史数据不会暂时覆盖更新的数据；先有可重复的耗时测量 |
| T2 | 本地变化历史 `history.jsonl` | done（模拟） | 仅在等级/区域/任务进度/装备变化时追加；有上限；不写入原始聊天；模拟测试覆盖 |
| T3 | 只读 MCP 服务器 | done（模拟） | 工具 `get_player_context`、`get_quests`、`get_equipment`（及可选 `get_recent_changes`）；每次响应重新计算新鲜度并带 `stale`、`capabilities`、`questLogMayBeIncomplete`；stdio 供 Claude/Codex；游戏字符串作为数据返回。本地 HTTP 传输移到 T4（只在需要 ChatGPT 时做） |
| T4 | ChatGPT 接入 | todo（需要游戏电脑） | D12：在游戏电脑上，ChatGPT 桌面客户端（Codex 设置）添加本地 stdio MCP `mcp-server.ps1`，能调用 get_player_context。不做隧道或云盘；只有要从别的设备访问时才重新考虑 |
| T5 | 实机端到端验证 | todo（需要游戏电脑） | 在 Windows 游戏电脑上：先 `git pull`，用 Windows PowerShell 5.1 跑 test-reader.ps1 和 test_mcp.py；T1–T3 在真实游戏中通过；按 INSTALL.md 安装（start.bat、install-mcp.bat、check-setup.bat 全部 PASS）；AI 通过 MCP 回答“下一步做什么”并说明数据年龄 |

## 后续（MVP 之后）

| ID | 任务 | 状态 | 验收条件 |
| --- | --- | --- | --- |
| T6 | 任务日志完整性（折叠分类） | todo | 找到 Forever 16001 的只读受支持接口；折叠前后任务 ID 集合一致；不自动操作界面。无可靠接口则保留标记并说明 |
| T7 | 实际游玩差分验证 | todo | 用户正常游玩时观察到坐标、任务进度、装备至少各一次变化；不自动控制角色 |
| T8 | 一键运行更可靠 | doing（目录自动查找 + check-setup 已做，模拟） | 自动发现 Forever 安装目录（多个候选时询问）；启动/停止按命令行核实进程而非旧 PID；第二台电脑路径不同也能运行 |
| T13 | 公开仓库 | done | 以干净的单一提交新建公开仓库；旧历史保留在私有存档仓库（D16） |
| T14 | macOS 支持 | doing | 脚本与启动文件已支持 Mac（D17），检测已在真实 Mac 安装上通过；等待第一次真实游戏运行 |
| T10 | 验证 Windows PowerShell 5.1 兼容 | doing（代码审查完成，需游戏电脑实测） | start.ps1、mcp-server.ps1、install-mcp.ps1 在 5.1 下通过测试（目前只在 7.7 上测过；已加 5.1 数组序列化修复） |
| T11 | 一键配置 MCP（install-mcp.bat） | done（模拟） | 自动写入 Claude Desktop（含 Microsoft Store 版路径）和 ~/.codex/config.toml；保留其他设置、备份、可重复、可卸载；实机未测 |
| T12 | 游戏顾问提示 what_next | done（模拟） | docs/ADVISOR.md 为唯一规则来源；MCP prompts/list、prompts/get；实机效果未测 |
| T15 | Forever 知识库 | todo | 先调研现有数据来源（如 Questie 是否有 Forever 数据、Forever 攻略站）；补充客户端拿不到的信息：怪物是否精英、掉落与掉率、NPC 位置；来源可追溯，不用经典版数据冒充 Forever |
| T16 | 云端远程 MCP（D20） | todo | 本机读取器把快照推到一个免费的托管服务；ChatGPT 自定义连接器（远程 MCP，HTTPS + 访问令牌）调用 get_player_context；推送策略（建议值）：等级/区域/子区域/任务/装备变化或坐标移动超过 3（地图百分比）时推送，最快每 30 秒一次；无变化时每 3 分钟心跳；远程 stale 阈值 4 分钟；令牌不进仓库；可关闭上传；先确认 ChatGPT 连接器要求和免费额度 |
| T9 | 日志量与恢复 | todo | 量化填充开销、落盘延迟、磁盘增长；I/O 异常恢复；同尺寸日志替换识别；不自动删除聊天日志 |

## 已完成

| ID | 任务 | 完成日期 | 证据 |
| --- | --- | --- | --- |
| D-0 | MVP 0：插件 → 聊天日志 → 读者 → player.json | 2026-11-26/27 | `docs/VALIDATION.md` 实机记录 |
| D-1 | 跨会话上下文机制（CLAUDE.md、TASKS、DECISIONS、会话结束规则） | 2026-11-27 | 旧仓库历史（D16） |
| D-2 | T1 启动扫描、T2 history.jsonl、T3 mcp-server.ps1 | 2026-11-27 | VALIDATION.md 模拟测试（PowerShell 7.7，Mac）；实机未验证 |
| D-3 | T11 install-mcp、T12 what_next 提示、5.1 修复 | 2026-11-27 | VALIDATION.md 第二批模拟测试；实机未验证 |
| D-5 | 公开前清理：去个人信息、样例 fixture、LICENSE、中英文 README/INSTALL | 2026-11-27 | 全部测试通过（模拟） |
| D-4 | INSTALL.md、游戏目录自动查找、check-setup、装备列表 bug 修复 | 2026-11-27 | VALIDATION.md 第三批模拟测试；实机未验证 |
