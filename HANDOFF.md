# 接续进度

## 当前状态（每次会话结束时重写本节）

更新：2026-11-27（第二次会话，Mac，无游戏）。

- 设计（D12）：游戏电脑上的桌面客户端（Claude Desktop、ChatGPT 桌面客户端的 Codex 设置、Codex）通过本地只读 MCP `mcp-server.ps1` 读取数据。不上云、不同步、不做隧道。DESIGN/CONTEXT 已更新。
- 已完成，**仅模拟测试**（Mac + PowerShell 7.7.0）：
  - T1：读取器启动时从末尾扫描，只发布最新完整快照。
  - T2：`history.jsonl` 只在发生变化时记录。
  - T3：`mcp-server.ps1`，4 个工具，外加 `what_next` 提示。
  - T11：`install-mcp.bat` 一键写入客户端配置。
  - T12：顾问规则写在 `docs/ADVISOR.md`。
- PowerShell 5.1：已代码审查并加数组序列化修复，未实际运行（T10）。
- 安装说明写在 `INSTALL.md`（用户、朋友、帮忙安装的 AI 都适用）。`start.bat` 会自动查找游戏目录；`check-setup.bat` 只读，逐项检查安装状态。
- **下一步要在 Windows 游戏电脑上做（T5、T4、T10）：** `git pull`，然后按 INSTALL.md 安装，直到 `check-setup.bat` 全部 PASS，再问“这个角色下一步做什么”。另外用 5.1 跑一遍测试。
- 仓库已重建为干净的公开仓库（D15、D16）；旧完整历史在私有的 `wow-context-bridge-archive`。别的电脑上旧的 checkout 要**重新 clone**。提交身份用 GitHub noreply，不用真名。
- 插件 Lua 没改，游戏不需要重新加载。

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

