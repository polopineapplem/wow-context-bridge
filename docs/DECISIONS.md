# 决策记录

只追加。每条写日期、决定、原因。推翻旧决定时新增一条并引用旧条目，不改写历史。

## D0 — 2026-11-26 — MVP 0 范围

插件 + 本地读者 → `player.json`；无 UI、无 MCP、无云、无公网端点、不读内存、不模拟输入。原因：用户要求最快的最小可行方案。详见 `DESIGN.md`。（其中“无 MCP”已被 D1 取代。）

## D1 — 2026-11-27 — 批准只读 MCP 服务器

用户要求任意 AI（ChatGPT、Claude 等）能读取最新游戏信息。取代 D0 中的“首轮不做 MCP”。MCP 只读，只暴露 `player.json` / 历史中的结构化数据，不提供任何游戏操作。

## D2 — 2026-11-27 — 存储先本地

`player.json`（最新）+ 有上限的 `history.jsonl`（仅变化时追加）。不用数据库或云。原因：轻量；之后可以扩展。

## D3 — 2026-11-27 — 先修启动，再做 MCP

启动时重放约 10 MB 历史会暂时发布旧快照；若先接 MCP，AI 可能拿到旧数据。因此 T1 在 T3 之前。

## D4 — 2026-11-27 — ChatGPT 接入方式待定

已核实（2026-11-27，来源见下）：ChatGPT 只能连接远程 HTTPS MCP 服务器，不能直接连本机；私有服务器可用 OpenAI Secure MCP Tunnel（出站连接，需工作空间开启开发者模式）。官方页面列出 Business/Enterprise/Edu 完整支持，Pro 仅 read/fetch，Plus 未列出。Claude Desktop/Claude Code/Codex 可直接用本地 stdio MCP，无需隧道。

待用户确认：ChatGPT 套餐；是否接受隧道或带令牌的公网地址。在此之前不创建任何公网端点。

来源：https://help.openai.com/en/articles/12584461-developer-mode-and-full-mcp-connectors-in-chatgpt-beta ，https://developers.openai.com/api/docs/guides/secure-mcp-tunnels

## D5 — 2026-11-27 — 直接提交到 main

个人项目，用户允许直接 commit/push 到 `main`，仅限本仓库。不 force-push。

## D6 — 2026-11-27 — 跨会话上下文放在仓库

仓库是唯一事实来源：`AGENTS.md`（规则，`CLAUDE.md` 引用它）、`HANDOFF.md`（当前状态）、`docs/TASKS.md`（看板）、`docs/DECISIONS.md`（本文件）。原因：跨 Claude/Codex/ChatGPT、跨电脑都可读；应用内记忆和聊天记录只在单机或单工具中存在。

## D7 — 2026-11-27 — 模型与推理强度

默认 Opus 5.5 medium。T1（日志边界情况）和 T3/T4（新鲜度与安全设计）用 high。

## D8 — 2026-11-27 — MCP 服务器用纯 PowerShell 实现

`mcp-server.ps1` 手写 stdio JSON-RPC（initialize/ping/tools/list/tools/call），不依赖 Python/Node 或 MCP SDK。原因：游戏电脑只保证有 Windows PowerShell 5.1，保持“零安装”。代价：协议需自行维护；已用官方 Python SDK 客户端核对兼容。以后若做 ChatGPT（远程 HTTP），可以在同一套工具函数上加 HTTP 传输，或改用 SDK。

## D9 — 2026-11-27 — 历史只记录变化

history.jsonl 只在等级、区域/子区域、任务增删/进度/完成、装备变化时追加；坐标移动不触发，避免每 15 秒一行。启动扫描找到的快照与历史最后一条比较，不重放旧快照。

## D10 — 2026-11-27 — 用户是 ChatGPT Plus

再次核实（2026-11-27）：OpenAI 官方文档没有写明 Plus 能否在 Plugins 页“Add custom MCP server”；第三方来源互相矛盾。官方文档确认：只接受远程服务器（SSE 或 streaming HTTP），支持“无认证”或 OAuth；带 `readOnlyHint` 的工具不需要逐次确认；可选 Secure MCP Tunnel，但未说明个人套餐能否使用。

结论：任何 ChatGPT 路线都需要一个 ChatGPT 能访问的 HTTPS 地址。候选按优先级：
1. Plus 有“Add custom MCP server”：给 mcp-server.ps1 加 streaming HTTP 传输（仅 127.0.0.1）+ 隧道。
2. 没有：自定义 GPT + Actions（Plus 可建 GPT），同一套数据以 OpenAPI 只读接口暴露，同样需要隧道。
3. 不接受公网地址：ChatGPT 不可行，用 Claude Desktop / Codex 的本地 MCP。

待用户：在 ChatGPT 网页确认是否有“Add custom MCP server”；是否同意带令牌的隧道（D4）。

来源：https://developers.openai.com/api/docs/guides/custom-mcp-server ，https://help.openai.com/en/articles/12584461-developer-mode-and-full-mcp-connectors-in-chatgpt-beta

## D11 — 2026-11-27 — Claude Pro 是最快可用路线

用户问 Claude Pro。Claude Pro 是包月订阅，不按 token 计费（有用量上限）。Claude Desktop 在游戏电脑上可直接加载本地 stdio MCP（README 已有配置），不需要隧道或公网地址，即 T5 可以直接用它验证。claude.ai 网页/手机端用远程自定义连接器，与 ChatGPT 一样需要 HTTPS 地址，归入 T4 同一方案。建议：先用 Claude Desktop 完成 T5，ChatGPT 并行等待 D10 的确认。

## D12 — 2026-11-27 — 用桌面客户端直接读本地数据

用户要求：不上云、不同步；用 ChatGPT 桌面客户端或 Claude 桌面客户端直接读游戏电脑上的本地文件。游戏是唯一事实来源。

做法：桌面客户端读本地文件靠的就是本地 MCP（客户端在本机启动一个程序），也就是现有的 `mcp-server.ps1`，不经过任何网络。
- Claude Desktop：支持本地 stdio MCP（README 配置）；也可以用官方 Filesystem 扩展直接读 player.json，但不会重新计算新鲜度。
- ChatGPT 桌面客户端：第三方资料称可以在其 Codex 设置里添加本地 stdio MCP（与 Codex CLI 共用配置），未找到 OpenAI 官方页面确认，需在游戏电脑上实测。网页版 ChatGPT 不读这个配置。
- 取代 D10 的隧道/云盘选项作为首选；那些只在要从别的设备访问时才考虑。

## D13 — 2026-11-27 — 一键配置与顾问规则

- `install-mcp.bat` 直接修改用户的 Claude Desktop 和 Codex 配置文件（用户要求“不手动”）。只改 `wow-context` 一个条目，每次改动前备份，`-Uninstall` 可撤销。
- 顾问规则只写在 `docs/ADVISOR.md` 一处：MCP 提示和直接读文件的 agent 共用。PowerShell 脚本保持 ASCII，所以用 HTML 注释标记截取正文，而不是匹配中文标题。
- 规则要求 AI 说明数据年龄，对 Forever 特有的位置信息不确定时直说，不要套用正式服或经典怀旧服的规则。

## D14 — 2026-11-27 — 面向朋友和 AI 助手的安装

用户希望别的电脑、朋友、帮忙安装的 AI 都能照着 GitHub 安装。做法：`INSTALL.md` 作为唯一安装说明（中文为主，附英文简版和 AI 助手步骤）；`start.bat` 不再写死 D 盘路径，改为自动查找，多个结果时要求用户选择，不猜；新增只读的 `check-setup.bat`，`-Json` 输出供 AI 使用。仓库仍是 private，是否公开由用户决定（T13）。

## D15 — 2026-11-27 — 公开前清理

用户决定先清理，之后公开。已做：
- 删除 `snapshots/`（真实角色快照）和两份原始会话记录。
- 测试改用 `tests/fixtures/player-sample.json`：角色名换成占位符，session 是假的，任务和装备等游戏数据保留。
- 从文档中去掉角色名、本机路径和聊天 ID。
- 加 MIT LICENSE（版权人写 GitHub 用户名）。
- 面向用户的 README 和 INSTALL 做成中英文两份；`docs/` 开发文档仍为中文。
- 取代 D0 时期“snapshots 是要求保存的私有备份”的约定。

未做：git 历史仍包含上述信息。公开前必须改写历史或新建干净仓库，两种做法都需要用户明确同意（AGENTS 禁止 force-push）。

## D16 — 2026-11-27 — 新建干净的公开仓库，旧仓库存档

不改写历史。原仓库（含真实快照备份、原始会话记录、真实姓名作者信息的完整历史）改名为 `polopineapplem/wow-context-bridge-archive`，保持 private。`polopineapplem/wow-context-bridge` 重新创建，从 D15 清理后的文件开始，只有一个提交，作者是 GitHub 用户名和 noreply 邮箱。以后的提交都用这个身份（仓库级 git config），不使用真实姓名或本机主机名。已有的 checkout 需要重新 clone。

## D17 — 2026-11-27 — 同时支持 Windows 和 macOS

用户在 Mac 上也装了 WoW Forever（`/Applications/World of Warcraft/_forever_`，macOS 版 1.60.1.71139 zhCN，有 `World of Warcraft.app`，没有 `Wow.exe`），要求两个平台都支持。插件 Lua 与平台无关。脚本改为：路径一律用 `/` 拼接；`lib/common.ps1` 同时识别 `Wow.exe` 和 `World of Warcraft.app`，在 Mac 上查找 `/Applications` 和 `~/Applications`，找到 macOS 的 Claude Desktop 配置；AI 客户端启动命令在 Windows 用系统 `powershell.exe`，在 macOS 用当前 `pwsh` 的真实路径。新增 `.command` 双击启动文件。macOS 需要先安装 PowerShell 7。取代此前“采集只支持 Windows”的说法。

## D18 — 2026-11-27 — macOS：受保护文件夹里的 checkout 改用 Application Support 存放运行文件

macOS 实机测试中，Claude Desktop 启动的 `pwsh mcp-server.ps1` 报 “Access to the path '…/Documents/wow-context-bridge/mcp-server.ps1' is denied”，工具不出现。原因是 macOS 隐私保护（TCC）：Claude.app 启动的子进程不能读 `~/Documents`。用户在“文件与文件夹”里打开 Claude 的权限并重启后仍然被拒（原因未查明）。终端和 Claude Code 能读，是因为它们有自己的授权。

做法：在 macOS 上，checkout 位于 `~/Documents`、`~/Desktop`、`~/Downloads` 或 iCloud 云盘（`~/Library/Mobile Documents`）时，`player.json`、`history.jsonl` 以及 `mcp-server.ps1` + `docs/ADVISOR.md` 的副本放在 `~/Library/Application Support/wow-context-bridge`。`install-mcp` 让客户端运行副本；`start` 每次启动刷新副本；`check-setup` 检查副本是否存在、是否与 checkout 一致。其他位置和 Windows 行为不变。环境变量 `WOW_CONTEXT_RUNTIME_DIR` 可以覆盖（测试用）。不依赖用户授予权限，也不要求用户移动 checkout。

## D19 — 2026-11-27 — 建议只用 Forever 客户端的数据

用户指出：第一次实机“下一步做什么”时，AI 用经典版的记忆猜任务位置和等级，这不对；Forever 有自己的内容。做法：插件 0.2.0 从 Forever 客户端读取任务等级、建议人数、任务日志分类（区域）、任务目标说明文字、当前地图上的任务位置和路点，并记录这些接口是否存在（`api`）；MCP 原样转交；`docs/ADVISOR.md` 规定只能用这些字段，缺失时直说没有数据，不得用经典版/正式服记忆补充。任务说明文字按任务 ID 只读一次（控制日志体积）。读文字需要临时选中任务日志条目，读完恢复，不算操作游戏。更完整的 Forever 知识库（NPC 位置、掉落等）另立任务 T15，先调研现有插件/数据来源再决定。

## D20 — 2026-11-27 — 用户选择：普通 ChatGPT 聊天通过云端远程 MCP 读取（待实施，T16）

普通 ChatGPT 聊天在 OpenAI 服务器上运行，读不到本机文件。用户比较了 Google Drive、S3 公开链接和自建远程 MCP 后，选择自建远程 MCP：本机读取器推送快照到托管服务，ChatGPT 通过自定义连接器调用。这改变了 D4/D12 和 AGENTS.md 中“只在本地、不自动上传”的边界，但仅限 T16 的实现：上传必须可关闭、需要访问令牌、令牌和地址不进公开仓库。实施前先确认 ChatGPT 连接器的实际要求和免费额度。本地 MCP 路径保持不变。
