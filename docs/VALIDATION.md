# 验证记录与证据边界

## 真实游戏测试

时间：2026-11-27 10:17–10:19，America/Los_Angeles。

环境：真实 Windows 文件系统和游戏进程；游戏电脑上的 `_forever_` 安装目录；客户端 1.60.1.71139，Interface 16001，zhCN。

实际链路：已安装 LocalContext → 游戏产生 LCB1 行 → 本地 WoWChatLog.txt → start.ps1 → player.json → 本地 Codex读取。

| 观察 | 结果 |
| --- | --- |
| 角色 | 作者的角色，22 级亡灵法师（姓名不在仓库中记录） |
| 位置 | 贫瘠之地，十字路口；x≈51.4918，y≈30.2935 |
| 当前任务 | 24 个；变异皮革为 9/20 |
| 已完成任务 | API 返回 214 个 ID，未逐个验证语义 |
| 装备 | 读到新月法杖 ID 6505、魔焰长袍 ID 7510 等 |
| 连续性 | 序号 153→156→160；153 到 156 的 capturedAt 相差 45 秒 |
| 最后一次核查 | ageSeconds=9，stale=false |
| API 分区 | capabilities 均 true，errors=[] |
| 限制 | realm 空字符串；questLogMayBeIncomplete=true |

这证明完整快照持续传输和中文编码可用。不能据此证明移动/换装/击杀的变化正确捕获，因为当时未实际执行这些动作。

## 模拟测试

`test-reader.ps1` 使用临时目录，调用实际 Windows PowerShell 读者：

- 无日志时等待且过期，不生成假角色。
- 中文任务、角色名正确往返；分段跨 65536 字节读取边界仍能重组。
- 装备 ID 和时间新鲜度正确。
- 含玩家私聊包装的行不进入输出。
- 缺一段时不发布快照。
- 历史时间标过期。
- 非法 UTF-8 拒绝。

`tests/test_addon.py` 通过 lupa 2.8 的 Lua 5.1 执行实际 Lua 源码、使用模拟 API，验证中文名、目标、装备、坐标、已完成 ID、战斗暂停和 API 缺失隔离。原开发过程还把模拟插件产生的日志交给实际读者解析；现有 portable 测试分别验证插件和读者，不包含这个额外集成断言。

首次上传前两组测试重新运行通过。当前文档补充不改变运行代码，没有将其宣称为一次新实机测试。

## 2026-11-27 模拟测试（T1–T3，Mac + PowerShell 7.7.0）

非实机。`test-reader.ps1` 全部通过，新增：10.8 MB / 201 个快照的日志启动直接得到最新快照（约 305 ms）；历史快照不写入 history；最新快照截断 + 半行时回退到上一个完整快照；会话切换取新会话；无快照的大日志保持 waiting；无变化不追加历史；等级/任务进度/装备变化写入一行；后台运行时追加快照被追读；日志被更短文件替换后重新扫描。

`tests/test_mcp.py` 16 项通过：初始化/版本协商、通知无响应、stdout 只有 JSON-RPC、4 个只读工具、中文字段、新鲜/历史/缺失/等待四种状态、未知工具报错。另用官方 MCP Python SDK 2.3.0 客户端连接成功（协商 2025-11-25，读出中文角色）。

未验证：Windows PowerShell 5.1 实际运行新代码（测试只在 PowerShell 7.7 上跑）；真实 Claude Desktop/Codex 在游戏电脑上的接入；真实游戏中的历史变化。

## 2026-11-27 模拟测试（第二批，Mac + PowerShell 7.7.0）

非实机。`tests/test_install_mcp.py` 12 项通过：预览不改文件、Claude/Codex 条目指向本 checkout、其他设置保留、数组不被 5.1 bug 改写、备份、重复运行不重复、生成合法 TOML（tomllib 解析）、卸载只删自己的条目、新建配置。`tests/test_mcp.py` 新增 4 项 prompts 测试（共 20 项）；官方 MCP Python SDK 2.3.0 能列出并取得 what_next。reader 16 项、Lua 插件测试仍全部通过。

PowerShell 5.1：只做了代码审查。已加 `Remove-TypeData System.Array` 防止 5.1 把数组序列化成 `{"value":...,"Count":...}`；仍需在游戏电脑上用 5.1 实际运行（T10）。

## 2026-11-27 模拟测试（第三批，Mac + PowerShell 7.7.0）

非实机。`tests/test_check_setup.py` 10 项通过：
- 游戏目录查找：只认 `_forever_`、忽略 `_retail_`、去重；唯一结果自动使用；多个时要求指定；错误路径报错清楚。
- check-setup：空环境报插件和读者缺失；MCP 冒烟测试；没有配置任何客户端时报错；完整环境全部 PASS；旧版插件报 WARN；读者停止报 FAIL。

另外修复一个 bug：`get_player_context` 的装备列表曾被合并成一条记录（PowerShell 函数返回数组的写法造成），已加回归测试（test_mcp.py 现为 21 项）。注册表查找和 Windows 盘符查找只在 Windows 上运行，未测试。

## 2026-11-27 macOS 实机测试

**真实游戏**，macOS 上的第一次实机运行（与上面的模拟测试分开）。环境：WoW Forever macOS 版 1.60.1.71139 zhCN，安装在 `/Applications/World of Warcraft/_forever_`，用户通过 Battle.net 启动并登录；PowerShell 7.7.0；读取器由 `start.command` 在单独的终端窗口运行。角色姓名不记录。

| 检查 | 结果 |
| --- | --- |
| `check-setup.ps1` | 8 项全部 PASS：平台 macOS / PS 7.7.0、游戏目录、插件与 checkout 一致、游戏日志含 LCB1、读取器在运行、MCP 4 个工具、Claude Desktop 已配置、Codex 已配置 |
| `player.json` | status=`snapshot_received`；22 级亡灵法师；贫瘠之地 / 十字路口；24 个任务；capabilities 全部 true；errors=[]；questLogMayBeIncomplete=true |
| 连续性 | 序号 2 → 4 → 5，相邻 capturedAt 相差 15 秒；年龄 1–15 秒；之后序号 7 年龄 15 秒、stale=false |
| MCP（stdio，直接调用 `mcp-server.ps1`） | `get_player_context` 返回 freshness 12 秒 / live；24 个任务（如 变异皮革 9/20）；12 件已穿装备；214 个已完成任务 |
| `history.jsonl` | 启动后 1 行基线记录 |

证明：插件、聊天日志、读取器、MCP 服务器整条链路在 macOS 实机可用，中文正常。尚未证明的内容见下方各小节（真实 AI 客户端、游玩中的变化、退出后的过期）。

## 尚未覆盖

- 多次角色切换、长时间运行、断电、重启和文件轮转压力。
- 游戏自然发生任务接受/进度/交付、移动/跨地图、换装时的差分。
- 折叠分类的完整任务数与原生日志对比。
- API secret/restricted 数据、不同副本环境、其他语言和其他版本。
- 读取器异常退出恢复、多个 Windows 会话、多游戏实例。
- 完整隐私安全审计和暴雪专项批准。

## 以后怎样记录新证据

每次记录客户端版本、语言、采样时间、会话/序号、新旧字段和所用测试类别。真实测试只记录结构化必要数据，不提交原始聊天日志。若用户正常游玩中没有发生某动作，记录“未观察到”，不要以模拟结果替代。
