# ChillNote Monorepo

ChillNote 仓库包含 3 个主要子系统：

- iOS 客户端: `chillnote/`、`chillnoteTests/`、`chillnoteUITests/`、`ChillNoteWidget/`
- 后端服务: `server/`
- 官网与落地页: `website/`

## 目录约定

- `docs/`: 项目文档
  - `docs/product`: 产品与设计文档
  - `docs/testing`: 测试文档
  - `docs/compliance`: 合规与上架文档
- `scripts/ops`: 运维/部署脚本
- `scripts/assets`: 图标与静态资源处理脚本

## 常用命令

- iOS 构建（示例）:
  - `xcodebuild -project chillnote.xcodeproj -scheme chillnote build`
- 后端开发:
  - `cd server && npm ci && npm run dev`
- 官网开发:
  - `cd website && npm ci && npm run dev`

## 兼容入口

以下根目录脚本保留为兼容入口，实际会转发到 `scripts/`：

- `./deploy.sh`
- `python3 process_icon.py`
- `python3 update_app_icon.py`
