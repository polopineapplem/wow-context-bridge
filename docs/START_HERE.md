# 新会话入口

本项目已完成从真实 WoW Forever 到本地 JSON 的最小链路。当前目标是让 AI 通过只读 MCP 读取最新角色信息（见 DECISIONS D1 与 TASKS）。本文档让不持有原聊天记录的新会话能够接续。

## 推荐阅读顺序

| 文件 | 用途 |
| --- | --- |
| [INSTALL](../INSTALL.zh-CN.md)（[English](../INSTALL.md)） | 用户/朋友/AI 助手的安装步骤 |
| [HANDOFF](../HANDOFF.md) | 当前状态、下一步、MVP 0 实机结果 |
| [TASKS](TASKS.md) | 任务看板（状态 + 验收条件） |
| [DECISIONS](DECISIONS.md) | 带日期的决策记录；推翻旧决定只追加 |
| [REMOTE_MCP](REMOTE_MCP.md) | T16 远程 MCP 调研：ChatGPT/Claude 连接器要求、Cloudflare 免费额度、推送量估算 |
| [CONTEXT](CONTEXT.md) | 原始诉求、会话背景、用户偏好、范围演变 |
| [DESIGN](DESIGN.md) | MVP 验收、方案选择和明确未做的事情 |
| [ARCHITECTURE](ARCHITECTURE.md) | 当前组件、数据流、生命周期和失败行为 |
| [PROTOCOL](PROTOCOL.md) | LCB1 日志封包、JSON 字段和新鲜度语义 |
| [VALIDATION](VALIDATION.md) | 真实测试与模拟测试的证据边界 |
| [RUNBOOK](RUNBOOK.md) | 另一台电脑继续、安装、测试、故障排查 |
| [SOURCE_NOTES](SOURCE_NOTES.md) | 上游源码、政策与产品能力来源 |

## 三个必须先知道的事实

1. 2026-11-27 在 Windows、Forever **1.60.1.71139 / Interface 16001 / zhCN** 上验证了真实角色、任务、装备、坐标和连续采样。
2. 游戏 API 返回的任务列表可能受折叠分类影响。已经读到数据不等于任务完整性已验收；当前状态会用 `questLogMayBeIncomplete` 提醒。
3. GitHub 保存代码和历史状态，没有接入实时同步。其他电脑无法仅凭 clone 仓库就读取原游戏电脑的新数据。

## 真正的事实来源

- 运行逻辑：`LocalContext/LocalContext.lua`、`start.ps1`。
- 实机结论：`VALIDATION.md`，标明了时间和版本。
- 当前游戏状态：仅运行中读者产生的新鲜 `player.json`；不存在就承认不可读。
- `tests/fixtures/player-sample.json`：去掉身份信息的样例，只用于测试，不是当前状态。
- MCP 已获批准但尚未实现；以 TASKS.md 状态为准。云连接、即时同步仍只是提案。

## 文档维护

本套文档最初以 MVP 0 代码的行为和当时观察到的结果为基础（旧提交历史在私有存档仓库，见 DECISIONS D16）。本文档提交不修改运行逻辑。未来修改行为时，连同相关协议/验收状态一起更新，并保留新证据的时间、版本和测试类别。
