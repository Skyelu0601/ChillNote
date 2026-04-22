# Scripts

- `scripts/ops`: 部署与运维脚本
- `scripts/assets`: 资源与图标处理脚本
- `scripts/i18n`: 国际化治理与质检脚本

根目录保留了兼容入口：

- `./deploy.sh` -> `scripts/ops/deploy.sh`
- `python3 process_icon.py` -> `scripts/assets/process_icon.py`
- `python3 update_app_icon.py` -> `scripts/assets/update_app_icon.py`

## Ops 命令

- `bash scripts/ops/deploy.sh`: 部署后端到生产服务器
- `sudo bash scripts/ops/setup-certbot-renew.sh`: 安装 Certbot 自动续签计划任务，避免 API 证书过期

## i18n 命令

- `npm run i18n:normalize`: 规范化 `Localizable.xcstrings`（补齐语言、修复空项、清理 `new`）
- `npm run i18n:reports`: 生成 `docs/i18n` 交付文档
- `npm run lint:i18n`: 国际化质量门禁检查
- `npm run i18n:stale`: 扫描 `stale` 条目，输出可安全清理的列表
- `npm run i18n:stale:apply`: 删除源码中已无引用的 `stale` 条目
- `npm run i18n:empty`: 扫描缺翻译内容的空条目，输出可安全清理的列表
- `npm run i18n:empty:apply`: 删除源码中已无引用的空条目
