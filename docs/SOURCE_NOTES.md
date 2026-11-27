# 来源与结论范围

本记录汇总原会话已访问和核查的来源。动态产品能力在真正实施时需要重新核实，不能凭旧聊天直接承诺。

| 来源 | 当时核实内容 | 不代表什么 |
| --- | --- | --- |
| [ForeverSync 项目](https://www.curseforge.com/wow/addons/wow-forever-friends) | 项目描述、隐私声明、Live Sync 介绍 | 不证明本项目已获支持或认证 |
| [ForeverSync 0.14.0 文件](https://www.curseforge.com/wow/addons/wow-forever-friends/files/9494820) | 下载并审阅实际 Lua 与 toc，版本 0.14.0，接口 16001/11509 | 不混同 forever-sync、friendssync 等其他项目 |
| [暴雪插件政策](https://eu.forums.blizzard.com/en/wow/t/wow-user-interface-add-on-development-policy/1642/1) | 公开插件政策边界 | 没有针对本桥的专项批准 |
| [OpenAI MCP 说明](https://help.openai.com/en/articles/12584461-developer-mode-and-full-mcp-connectors-in-chatgpt-beta) | 当时文档提及远程 MCP 与 Secure MCP Tunnel | 未确认用户账户资格，未实际接入 |
| 本机 .build.info、实际日志和 player.json | 1.60.1.71139；LCB1 真实传输、中文、任务/装备等 | 不覆盖其他电脑或未来客户端版本 |
| 原参考聊天 | 用户需求和方案演变 | 助手早期提案不是实现事实 |

ForeverSync 源码核查定位：ForeverSync.lua 约 579–646 行涉及 FS1、LoggingChat、SendSystemMessage 和填充；约 1034–1060 行涉及登录输出。完成任务读取支持 GetAllCompletedQuestIDs，但其登录 Live Sync 流并不是完整历史已完成任务快照。任务目标主要存储完成状态和数量，不足以满足本项目要求的中文文本。没有发现所需已穿装备导出。

原始下载留在原工作区 work/，未提交第三方完整源码或依赖二进制到仓库。LocalContext 为本项目独立实现。Lua 文件现有注释写 MIT，但仓库尚无完整 LICENSE 文件；若以后公开发行，应单独整理正式许可与归属，不将当前私有备份当作完整发行包。
