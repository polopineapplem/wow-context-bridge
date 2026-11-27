# 远程 MCP 调研（T16 / D20 / D21）

调研日期：2026-11-27。以下内容来自官方页面（经网页抓取的摘要，不是逐字引用）。页面会变，实施前在自己的账户界面再确认一次。

## 结论（先看这里）

1. **ChatGPT Plus 不能添加自定义远程 MCP 服务器（按 OpenAI 官方帮助页）。** 官方写明：自定义 MCP 服务器与完整 MCP 支持面向 Business、Enterprise/Edu；Pro 可以连接自定义 MCP，但只有读取/获取权限；Free、Go、Plus 没有列出。用户是 Plus（D10），所以按 T16 的要求**停止实施，先报告**（D21）。
2. **ChatGPT 自定义连接器的认证只有 OAuth、无认证、或两者混合。** 文档没有静态 Bearer 令牌或自定义请求头。即使换到 Pro，也必须做 OAuth（或无认证 + 不可猜的地址），不能只靠任务里设想的“访问令牌”。
3. **自定义 GPT + Actions（支持 API Key/Bearer）不是替代方案**：OpenAI 正在退役自定义 GPT，标准退役日期 2026-12-11，Actions 迁移到 plugins 后 API Key 凭据无对应方式（社区报告）。
4. **同一个远程 MCP 可以直接给 claude.ai 网页/手机使用**：Claude 的自定义连接器（远程 MCP）在 Free（限 1 个）、Pro、Max 等方案都可用，并且可以在“Request headers”里填 Bearer 令牌。用户有 Claude Pro（D11）。
5. **托管选 Cloudflare Workers + SQLite Durable Object**：推送量远低于免费额度；KV 每天 1000 次写入在长时间游玩时不够。

## ChatGPT 自定义 MCP 连接器

| 项目 | 官方说法 | 来源 |
| --- | --- | --- |
| 方案 | 自定义 MCP 与完整 MCP：Business、Enterprise/Edu（网页版）。Pro：可连接自定义 MCP，仅读取/获取权限。Free/Go/Plus 未列出 | [帮助：Connecting custom MCP servers in ChatGPT](https://help.openai.com/en/articles/12584461-developer-mode-and-full-mcp-connectors-in-chatgpt-beta) |
| 入口 | 不必先开 Developer Mode。Plugins → “+” → Add custom MCP server → 填名称和 URL → 配置认证 → 勾选风险确认 → Create as a plugin；安装后在对话里用 @ 选择。旧入口：设置里的 Apps → Create | 同上 |
| 传输 | SSE 与 streaming HTTP | [开发者文档：Add custom MCP server](https://developers.openai.com/api/docs/guides/custom-mcp-server) |
| 认证 | OAuth、无认证、混合（OAuth 或无认证）。OAuth 可用静态客户端凭据，否则用 CIMD 或 DCR。没有静态 Bearer/自定义请求头 | 同上 |
| 工具标注 | 遵守 `readOnlyHint`；没有该标注的工具视为写操作，默认需要确认 | 同上 |
| search/fetch | 不再要求（公司知识库功能除外） | 同上 |
| 地址 | 必须是公网 HTTPS；本地 MCP 不能直接连接，私有网络可用 Secure MCP Tunnel | 帮助页同上 |
| 其他 | 连接器概览 | [帮助：Connected apps in ChatGPT](https://help.openai.com/en/articles/11487775-connectors-in-chatgpt) |

第三方博客对 Plus 的说法互相矛盾（有的说 Plus 有 Developer mode beta），以官方帮助页为准。用户可以在自己账户里直接确认：ChatGPT 网页 → Plugins → “+”，看有没有“Add custom MCP server”。如果有，再按“如果继续”一节实施。

自定义 GPT Actions：[GPT Actions 帮助页](https://help.openai.com/en/articles/9442513-gpt-actions)（认证可选 None/API Key/OAuth，自定义 GPT 退役日期 2026-12-11），[社区报告：迁移后 API Key 凭据缺失](https://community.openai.com/t/custom-gpt-plugin-migration-removed-critical-action-integration-with-no-supported-credential-replacement/1403291)。

## Claude 自定义连接器（对照）

- 方案：Free（1 个）、Pro、Max、Team、Enterprise 等；入口在 Settings → Connectors（或“+” → Add custom connector）。
- 认证：推荐 OAuth（Claude 发布的 CIMD）；服务器用固定凭据时，在“Request headers”里填 API Key 或 Bearer 令牌，加密保存。
- 来源：[Get started with custom connectors using remote MCP](https://support.claude.com/en/articles/11175166-get-started-with-custom-connectors-using-remote-mcp)，[Claude 文档：remote MCP](https://claude.com/docs/connectors/custom/remote-mcp)

## Cloudflare 免费额度（Workers Free）

| 产品 | 免费额度 | 来源 |
| --- | --- | --- |
| Workers | 每天 10 万请求（UTC 0 点重置），每请求 CPU 10 ms，128 MB 内存 | [Workers limits](https://developers.cloudflare.com/workers/platform/limits/)，[Workers pricing](https://developers.cloudflare.com/workers/platform/pricing/) |
| Durable Objects（仅 SQLite 后端） | 每天 10 万请求、13,000 GB-s；SQL 每天读 500 万行、写 10 万行；共 5 GB。`ctx.storage.put/get` 按行计费（每次 put 记 1 行写入）。Worker 调 DO 每次算 1 个请求；alarm 算请求 | [DO pricing](https://developers.cloudflare.com/durable-objects/platform/pricing/)，[DO limits](https://developers.cloudflare.com/durable-objects/platform/limits/) |
| KV | 每天读 10 万、写 1000（不同 key）、同一 key 每秒最多 1 次写入；1 GB | [KV limits](https://developers.cloudflare.com/kv/platform/limits/) |
| D1 | 每天读 500 万行、写 10 万行；单库 500 MB、共 5 GB；2026-09-01 起超额直接报错 | [D1 limits](https://developers.cloudflare.com/d1/platform/limits/)，[D1 pricing](https://developers.cloudflare.com/d1/platform/pricing/) |

DO limits 页面对单个对象的存储上限前后不一致（表格 10 GB，FAQ 说免费 1 GB）；本项目只存一份快照和少量历史，远低于两者。

## 推送量估算（D20 的推送参数）

- 最坏情况：整天每 30 秒推送一次 = 2,880 次/天。
- 读取器开着但没在玩：每 3 分钟心跳 = 480 次/天。
- 典型：玩 8 小时（变化频繁，约 960 次）+ 其余 16 小时心跳（320 次）≈ 1,280 次/天。

| 存储 | 每次推送消耗 | 是否够用 |
| --- | --- | --- |
| KV | 1 次写入 | 不够：典型一天约 1,280 次，超过 1,000 次；超额后写入失败 |
| Durable Object（SQLite） | 1 个 DO 请求 + 1–2 行写入 | 够：最坏 2,880 请求/天、约 5,760 行写入/天，远低于 10 万 |
| D1 | 1–2 行写入 | 够；但多一个数据库要管理，单用户场景 DO 更简单 |

AI 读取：每次工具调用约 1 个 Worker 请求 + 1 个 DO 请求，几百次/天也可忽略。CPU：解析和返回一份 30–60 KB 的快照预计在 10 ms 以内，需要部署后实测。

## 如果继续（未实施，等用户决定）

方案设计保留在这里，用户选择后再实现：

- `remote/`：一个 Cloudflare Worker + 一个 SQLite Durable Object。
  - `POST /upload`：`Authorization: Bearer <上传令牌>`，存最新快照（去掉原始聊天，只存 player.json 的字段）和最近的变化历史。
  - `/mcp`：streamable HTTP，工具与 `mcp-server.ps1` 相同（只读、`readOnlyHint`），`what_next` 提示用 `docs/ADVISOR.md` 正文；新鲜度在服务器端计算，stale 阈值 4 分钟。
  - 读取认证：Claude 用请求头 Bearer 令牌（与上传令牌分开）；ChatGPT（若可用）需要 OAuth，或无认证 + 地址里不可猜的随机路径（较弱，地址泄露即可读取）。
- 本地上传：读取器里可选开启（默认关闭），地址和令牌放在仓库外、不提交的本地配置；推送策略按 D20。
- 部署（`wrangler login`、`wrangler deploy`、`wrangler secret put`）和令牌生成由用户执行。
