# 版本资料（game profile）

文件：`config/game-profile.json`。决策见 DECISIONS D23。

用途：让顾问知道 WoW Forever（魔兽世界：无限）是什么、和经典怀旧服/正式服哪里不同、该信哪些来源，避免把经典版或正式服的记忆当成 Forever 的事实。它是仓库里的静态数据：MCP 服务器只从磁盘读，运行时不联网。调研在修改资料时由人或 agent 完成。

## MCP 怎么用它

- `get_game_profile` 工具：返回 `versionCheck` 和完整资料。
- `get_player_context` 多一个 `gameProfile` 字段，就是 `versionCheck`。
- `what_next` 提示：`docs/ADVISOR.md` 正文后面附资料摘要（产品说明、阶段、版本警告、advisorRules、facts）。
- `initialize` 的 instructions 提到 `get_game_profile`；版本不匹配时附上警告。
- macOS 受保护目录（D18）：`start`/`install-mcp` 会把资料复制到运行目录的 `config/`。
- 测试或特殊部署可用 `mcp-server.ps1 -ProfilePath <文件>` 指定。

`versionCheck.status`：

| 值 | 含义 |
| --- | --- |
| `match` | `client.version` 与 `client.interface` 一致，build 在 `verifiedBuilds` 里 |
| `build_differs` | version/interface 一致，build 不在列表里（多半是热修）；`matches=true`，`notes` 里有提示 |
| `mismatch` | version 或 interface 不一致；`matches=false`，`warning` 要求告诉用户建议可能不适用 |
| `unknown` | 快照没有 `client` 信息（没有角色数据，或旧快照） |
| `no_profile` | 找不到或解析不了资料文件 |

locale 不在 `verifiedLocales` 里时只加一条 `notes`（中文名称只核对过这些语言），不算不匹配。

## 字段

- `schemaVersion`、`profileId`（如 `wow-forever-1.60.1`）、`updatedAt`（最后一次调研日期）。
- `product`：名称（含 zhCN“无限”、zhTW“永恆”）、一段简介 `summary`、`isNot`（容易混淆的版本）、`tocGameType`。
- `client`：`version`、`interface`（数组）、`verifiedBuilds`（实机或调研核对过的 build）、`verifiedLocales`、`note`。
- `phase`：当前阶段、置信度、来源、日期。
- `facts[]`：`id`、`topic`、`fact`（自己的话，中文）、`confidence`（high = 官方来源或多个来源一致；medium = 单一第三方或测试期资料；low = 只有社区说法）、`sources`（指向 `sources[].id`）、`asOf`。
- `differences.vsClassicEra` / `vsRetail` / `unverified`。
- `conflicts[]`：来源之间不一致或可能过时的点。
- `sources[]`：`id`、`priority`（1 官方 > 2 Forever 专用数据库/维基 > 3 明确写了 Forever 的攻略 > 4 社区）、`type`、`name`、`url`、`date`、`appliesTo`。
- `searchHints[]`：按优先级给 AI 和用户的查找提示（站点、中英文关键词）；`searchAvoid[]`：不要用的搜索结果。
- `advisorRules[]`：顾问必须遵守的规则，原样进入 `what_next` 提示。

## Forever 更新时怎么改

1. 看新客户端的 `client.version`/`build`/`interface`（实机快照或 `.build.info`）。只是 build 变了：把新 build 加进 `verifiedBuilds`，再查一下热修帖有没有改到 `facts`。version 或 interface 变了：新建一份资料，或者改 `profileId` 和 `client`，然后重新核对全部 `facts`。
2. 按 `sources` 的优先级重新查：官方热修/补丁说明 → Wowhead Forever / Warcraft Wiki → 攻略站 → NGA/Reddit。每个来源记 URL、日期和适用版本。
3. 只用自己的话总结，不复制攻略原文，不放长引用。
4. 来源之间矛盾的写进 `conflicts`，没查到的写进 `differences.unverified`，不要硬写成事实。
5. 改 `updatedAt`、`phase`，运行 `python tests/test_mcp.py`。
6. 资料不含角色数据，可以提交。

## 2026-11-27 首次调研的局限

- Wowhead 指南页正文抓不到（只拿到页头和日期），相关事实来自搜索摘要，按 medium 处理。
- 官方中文职业文章是测试期（2026-10-10）的，上线后热修还在改职业。
- 没有找到整体升级速度、是否有随机副本查找器、骑术价格的可靠说法。
- build 1.60.1.71139 本身没有官方补丁说明，只有第三方记录和 11-25 热修帖。
