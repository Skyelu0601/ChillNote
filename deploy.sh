#!/bin/bash

# ChillNote 后端精简部署脚本
# 用法:
#   ./deploy.sh
#   PUSH_ENV=1 ./deploy.sh              # 同步本地 server/.env 到服务器
#   PUSH_ENV=1 LOCAL_ENV_FILE=./server/.env ./deploy.sh

set -euo pipefail

SERVER_IP="45.43.57.244"
SERVER_USER="root"
LOCAL_SERVER_DIR="./server"
LOCAL_ENV_FILE="${LOCAL_ENV_FILE:-$LOCAL_SERVER_DIR/.env}"
PUSH_ENV="${PUSH_ENV:-0}"

echo "🚀 开始部署 ChillNote 后端..."

# 1. 本地准备
if [ ! -d "$LOCAL_SERVER_DIR" ]; then
    echo "❌ 错误: 找不到 server 目录"
    exit 1
fi

echo "🔨 本地编译 TypeScript..."
pushd "$LOCAL_SERVER_DIR" >/dev/null
npm install
npm run build
popd >/dev/null

echo "📦 打包后端代码..."
cd "$LOCAL_SERVER_DIR"
COPYFILE_DISABLE=1 COPY_EXTENDED_ATTRIBUTES_DISABLE=1 tar -czf ../server-deploy.tar.gz \
    --exclude='node_modules' \
    --exclude='uploads' \
    dist/ \
    prisma/ \
    ecosystem.config.cjs \
    package.json \
    package-lock.json
cd ..

# 2. （可选）推送 .env
if [ "$PUSH_ENV" = "1" ]; then
  echo "🔐 推送本地 .env 到服务器..."
  if [ ! -f "$LOCAL_ENV_FILE" ]; then
    echo "❌ 错误: 找不到本地 .env: $LOCAL_ENV_FILE"
    exit 1
  fi
  scp "$LOCAL_ENV_FILE" ${SERVER_USER}@${SERVER_IP}:/tmp/chillnote-api.env
fi

# 3. 上传代码包
echo "📤 上传代码到服务器..."
scp server-deploy.tar.gz ${SERVER_USER}@${SERVER_IP}:/tmp/

# 4. 服务器端部署
echo "🔧 在服务器上安装和启动..."
ssh ${SERVER_USER}@${SERVER_IP} << 'ENDSSH'
set -euo pipefail

BASE_DIR="/root/chillnote-api"
APP_DIR="$BASE_DIR/current"

mkdir -p "$APP_DIR"
cd "$BASE_DIR"

# 写入 .env（如果推送了）
if [ -f "/tmp/chillnote-api.env" ]; then
  echo "🔐 写入 $APP_DIR/.env..."
  install -m 600 "/tmp/chillnote-api.env" "$APP_DIR/.env"
  rm -f "/tmp/chillnote-api.env"
fi

if [ ! -f "$APP_DIR/.env" ]; then
  echo "❌ 错误: 未检测到 $APP_DIR/.env"
  exit 1
fi

echo "📦 解压代码..."
rm -rf "$APP_DIR/dist" "$APP_DIR/prisma"
tar -xzf /tmp/server-deploy.tar.gz -C "$APP_DIR"
rm /tmp/server-deploy.tar.gz

cd "$APP_DIR"

echo "📥 安装生产依赖..."
export NODE_ENV=production
npm ci --only=production || npm install --only=production

echo "🔧 生成 Prisma 客户端并迁移..."
npx prisma generate
npx prisma db push --accept-data-loss

if ! command -v pm2 &> /dev/null; then
    echo "📥 安装 PM2..."
    npm install -g pm2
fi

echo "🚀 重启应用..."
pm2 delete chillnote-api 2>/dev/null || true
pm2 start "$APP_DIR/ecosystem.config.cjs" --only chillnote-api --update-env
pm2 save

echo "✅ 部署完成！"
ENDSSH

# 5. 清理本地临时文件
echo "🧹 清理临时文件..."
rm -f server-deploy.tar.gz
