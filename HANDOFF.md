# 接续进度

## 当前状态（每次会话结束时重写本节）

更新：2026-11-27（第五次会话，Mac，T19 版本资料；**只做了模拟测试，没有实机测试**）。

- **T19 完成（模拟，D23）**：调研了 WoW Forever（魔兽世界：无限）。这是 2026-11-04 上线的独立产品线：60 级，没有服务器而是规则集，新增区域/任务/9 个副本/天裔种族/新种族职业组合，天赋和专业都大改，团队副本据报道 2026-12-09 开放。结果写进 `config/game-profile.json`（事实带来源、日期、置信度、冲突、未验证项、可信来源和中英文搜索提示、顾问规则），字段和更新方法见 `docs/GAME_PROFILE.md`。
- MCP 服务器 0.4.0：新工具 `get_game_profile`；`get_player_context` 多了 `gameProfile` 版本检查；`what_next` 附资料摘要；version/interface 与资料不符时在工具结果、initialize 说明和提示里都给警告。运行时不联网。`docs/ADVISOR.md` 增加资料用法（依据优先级、“通用经验，未针对 Forever 验证”、“不确定”）。
- 验证：test_mcp（新增 14 项）、test_install_mcp、test_check_setup、test-reader、test_addon（lupa 2.8，临时 venv）全部通过，PowerShell 7 / macOS。**真实 AI 在新提示下的回答没有测**；已在运行的 Claude Desktop 需要完全退出重开（并在 macOS 上运行一次 start.command 或 install-mcp.command 刷新 Application Support 副本）才会加载新服务器。
- 不确定的：整体升级速度、是否有随机副本查找器、骑术价格、新区域/副本的中文正式名和准确等级、build 71139 的官方说明。
- 同日另一会话的 T16（claude.ai 远程 MCP，D22）状态见下面一段；`remote/src/advisor.js` 已用 sync 脚本重新生成，但远程 Worker 还没有 `get_game_profile`（T21）。
- **下一步**：在 Mac 上刷新副本、重开 Claude Desktop，问一次“下一步做什么”，确认回答引用版本资料、标注通用经验、不编坐标（T19 实机部分）；12-09 后更新 phase（T20）。其余仍是 T4、T7、T10。

T16（第四次会话，Mac；**只有模拟测试，没有部署，没有实机**）。

- **ChatGPT 阻塞（D21）**：官方文档显示 Plus 不能加自定义远程 MCP，且 ChatGPT 只支持 OAuth/无认证。另立 T18。
- **claude.ai 远程 MCP 已实现（D22）**：
  - `remote/`：Cloudflare Worker + SQLite Durable Object；`POST /upload`（上传令牌）、`POST /mcp` 或 `/mcp/<读取令牌>`（读取令牌）；工具和 what_next 与 `mcp-server.ps1` 相同；远程 stale 240 秒。
  - `lib/remote.ps1` + `start.ps1`：可选上传，默认关闭；推送策略按 D20（变化/移动>3 → 最快 30 秒一次，3 分钟心跳），失败退避。
  - `configure-remote.ps1`（.bat/.command）：在仓库外生成 `remote.json` 和两把随机令牌，`-SetSecrets` 调 wrangler 存 secret，`-Check` 测试，`-Disable` 关闭，`-ShowConnector` 显示 Claude 连接器设置。`check-setup` 显示上传开关。
  - 文档：README/INSTALL 中英文“Optional: Claude on the web and phone”，PROTOCOL、ARCHITECTURE、REMOTE_MCP、VALIDATION、AGENTS.md。
- **验证（模拟）**：`tests/test-remote-push.ps1` 33 项；`node --test remote/test/*.test.mjs` 11 项（含 start.ps1 → 本机 Worker 代码 → MCP 端到端）；test-reader、test_mcp、test_install_mcp、test_check_setup 通过（PowerShell 7.7.0，Node 26）。test_addon 未跑（插件未改）。
- **未验证**：真实 `wrangler deploy`/`secret put`、Cloudflare 上运行、claude.ai 连接器（请求头是 beta，可能只能用路径令牌）、Windows PS 5.1 上传。
- **下一步（用户操作）**：按 INSTALL.md 可选章节：`cd remote` → `npx wrangler@4 login` → `npm run deploy` → `./configure-remote.command`（粘贴地址）→ `./configure-remote.command -SetSecrets -Check` → 重启 start.command → claude.ai 添加连接器 → 问“下一步做什么”。然后把结果记进 VALIDATION（实机），T16 验收。本地方面仍待 T4（ChatGPT 桌面 Codex）和 T7。

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

