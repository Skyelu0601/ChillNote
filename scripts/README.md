# Scripts

- `scripts/ops`: 部署与运维脚本
- `scripts/assets`: 资源与图标处理脚本
- `scripts/i18n`: 国际化治理与质检脚本

根目录保留了兼容入口：

- `./deploy.sh` -> `scripts/ops/deploy.sh`
- `python3 process_icon.py` -> `scripts/assets/process_icon.py`
- `python3 update_app_icon.py` -> `scripts/assets/update_app_icon.py`

## i18n 命令

- `npm run i18n:normalize`: 规范化 `Localizable.xcstrings`（补齐语言、修复空项、清理 `new`）
- `npm run i18n:reports`: 生成 `docs/i18n` 交付文档
- `npm run lint:i18n`: 国际化质量门禁检查
