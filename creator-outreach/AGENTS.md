# Creator Outreach Instructions

修改或运行本项目之前，完整阅读 [OUTREACH_RULES.md](OUTREACH_RULES.md)；该文件统一维护线索筛选、已批准文案、Affiliate 权益、Offer Code、发送审批及暂停恢复规则，不在此重复。

- `data/leads.csv` 是线索与发送历史的事实来源；保留已发送、退信、拒收和回复记录，发送结果与 message ID 立即落盘。
- 不并行运行两个写入线索或发送邮件的进程；不暴露 `.env.local`、邮箱密码或 API 密钥。
- 付费抓取和真实发送使用现有显式参数与精确确认；先完成获授权的本地准备，确认针对实际名单与费用。普通代码修改、读取和本地测试无需发送确认。

## Verification

代码逻辑变更在 `creator-outreach/` 运行 `npm test`。涉及发送或文案时，检查本地预览；连接测试、付费抓取和真实发送不属于普通代码验证。
