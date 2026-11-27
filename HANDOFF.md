# 接续进度

## 当前状态（每次会话结束时重写本节）

更新：2026-11-27（第三次会话，Mac，**真实游戏**）。

- **macOS 第一次实机运行通过**（详见 `docs/VALIDATION.md`“2026-11-27 macOS 实机测试”）：check-setup 全 PASS；真实 Claude Desktop 通过 MCP 读到 live 数据；退出游戏 65 秒后 stale=true；读到时数据一般 2–13 秒前。
- **修复（D18）**：macOS 不允许 Claude 启动的 MCP 读 `~/Documents`（开权限也不行）。checkout 在文稿/桌面/下载/iCloud 时，`player.json`、`history.jsonl` 和 MCP 服务器副本放 `~/Library/Application Support/wow-context-bridge`；install-mcp 指向副本，start 刷新副本，check-setup 检查副本。有回归测试。
- **插件 0.2.0（D19）**：从 Forever 客户端读取任务等级、日志分类、目标说明、地图位置，ADVISOR 禁止用经典版记忆。已在游戏 /reload 后实机确认（api 探测结果在 VALIDATION）。
- 本机：读取器由 `start.command` 在终端窗口运行；Claude/Codex 配置指向 Application Support 里的副本（有 .bak）。
- 测试（PowerShell 7.7.0，`PWSH=~/.local/bin/pwsh`）：test-reader、test_mcp、test_install_mcp、test_check_setup 全过；test_addon 用 lupa 2.8（临时 venv）通过。
- **未做/未验证**：ChatGPT 桌面应用的 Codex（T4）；游玩中的任务/区域/装备变化（T7，本轮角色没动）；Claude Chat 里用户提问的回答未记录；Windows 上 5.1 实测（T10）。
- **新任务**：T15 Forever 知识库（精英、掉落、NPC 位置）；T16 云端远程 MCP（D20，用户已选方案 B 与推送参数）。
- **下一步**：做 T16（单独会话）；本地方面在 ChatGPT 桌面应用的 Codex 里问“这个角色下一步做什么？”并在正常游玩时观察 T7 变化。

---

以下为 2026-11-27 MVP 0 交接记录。

完整上下文入口：[docs/START_HERE.md](docs/START_HERE.md)。本文件保留简明交接，详细设计、架构、协议和测试边界见该索引。

用户目标：最轻量的本地 WoW Forever 上下文桥；无 UI、无手动复制粘贴、一个启动脚本；首轮不做 MCP、不做云数据库、不公开端点、不读游戏内存、不自动操作游戏。用户要求保存到私有 GitHub 仓库，以便其他电脑继续。

## 真实验证结果

2026-11-27 10:17–10:19 America/Los_Angeles，在真实 Windows 游戏电脑读取成功：

- 客户端 1.60.1.71139，Interface 16001，zhCN。
- 作者的角色：22 级亡灵法师（姓名不记录）。
- 贫瘠之地 / 十字路口，约 51.4918, 30.2935。
- 24 个当前任务；API 返回 214 个已完成任务 ID（未判定其是否含隐藏追踪任务）。
- 示例：变异皮革 9/20；装备新月法杖、魔焰长袍等，ID/中文均正常。
- 序号 153→156→160 连续增加，末次读取时年龄 9 秒、stale=false，errors=[]。
- 服务器名返回空字符串，不要猜测。
- questLogMayBeIncomplete=true，折叠分类可能影响完整性。
- 未执行移动、换装、击杀，因此不能宣称这些变化已单独验证。

原先保存的真实历史快照已在公开前移除（D15）。测试用的是去掉身份信息的 `tests/fixtures/player-sample.json`，它是模拟数据，不是当前状态。

## 技术方案与研究

本机原先没有 ForeverSync。下载审阅的是 CurseForge `wow-forever-friends` 的 ForeverSync 0.14.0（文件 9494820），不是名字相近的其他项目。

源码证实：通过 SendSystemMessage / LoggingChat 生成 FS1 日志行，约 50 KB 填充推进落盘；位置每 30 秒检查，阈值 2%，非紧急刷盘最长等待约 120 秒。任务输出缺完整中文文本，未提供所需的已穿装备快照，因此选择独立实现 LocalContext。未复制 GPL 源码；只复用传输思路。

来源：https://www.curseforge.com/wow/addons/wow-forever-friends/files/9494820

政策：https://eu.forums.blizzard.com/en/wow/t/wow-user-interface-add-on-development-policy/1642/1

只能说明使用游戏 API 和本地文件，不能宣称获得暴雪认证。

## 测试与当前限制

PowerShell 模拟测试覆盖：缺失日志、中文、跨缓冲区分段、装备字段、私聊过滤、不完整快照、过期数据和非法 UTF-8。Lua 5.1 模拟运行真实插件源码，覆盖任务/装备/中文/坐标、战斗暂停、缺失已完成任务 API 隔离。插件产生的模拟日志曾交给实际 PowerShell 读者验证。实机验证结论见上方。

启动较慢的实际原因：旧读取器已退出，原 PID 被系统进程复用；未终止那个系统进程。重启读者从日志起点重放约 10 MB 历史快照，导致启动期间依次发布旧数据，随后追上最新数据。还需等待至少一次 15 秒采样来验证持续更新。

下一步优先级：见 [docs/TASKS.md](docs/TASKS.md)（原列表已迁入 T1、T6、T7、T8、T4）。

其他边界：同尺寸快速替换日志未专门处理；停止读取器不会停止游戏内插件或聊天记录；不要删除原始聊天日志。插件仅接口版本 16001 输出。现有源脚本硬编码默认 D 盘路径，但有 -GameRoot 参数。

## 另一台电脑的 Codex

读取本文件、README 和源码后继续，不必重新研究整个方案。先核实新电脑是否有游戏及安装版本；没有游戏也能开发并运行模拟测试，但不能声称实机验证。原游戏电脑的实时文件不会通过 GitHub自动更新，仓库只保存本次提交时的代码和历史状态。

