#!/bin/bash

# ChillNote 后端精简部署脚本
# 用法:
#   ./deploy.sh
#   PUSH_ENV=1 ./deploy.sh              # 同步本地 server/.env 到服务器
#   PUSH_ENV=1 LOCAL_ENV_FILE=./server/.env ./deploy.sh
#   RESOLVE_ROLLED_BACK=20260211194000_invite_rewards_mvp ./deploy.sh
#     # 在服务器执行 migrate deploy 前，先对指定 migration 执行 resolve --rolled-back

set -euo pipefail

SERVER_IP="45.43.57.244"
SERVER_USER="root"
LOCAL_SERVER_DIR="./server"
LOCAL_ENV_FILE="${LOCAL_ENV_FILE:-$LOCAL_SERVER_DIR/.env}"
PUSH_ENV="${PUSH_ENV:-0}"
RESOLVE_ROLLED_BACK="${RESOLVE_ROLLED_BACK:-}"

echo "🚀 开始部署 ChillNote 后端..."

# 1. 本地准备
if [ ! -d "$LOCAL_SERVER_DIR" ]; then
    echo "❌ 错误: 找不到 server 目录"
    exit 1
fi

echo "🔨 本地编译 TypeScript..."
pushd "$LOCAL_SERVER_DIR" >/dev/null
npm ci
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
ssh ${SERVER_USER}@${SERVER_IP} "RESOLVE_ROLLED_BACK='${RESOLVE_ROLLED_BACK}' bash -s" << 'ENDSSH'
set -euo pipefail

BASE_DIR="/root/chillnote-api"
APP_DIR="$BASE_DIR/current"
SHARED_DIR="$BASE_DIR/shared"
SHARED_ENV_FILE="$SHARED_DIR/.env"
RESOLVE_ROLLED_BACK="${RESOLVE_ROLLED_BACK:-}"

mkdir -p "$APP_DIR"
mkdir -p "$SHARED_DIR"
cd "$BASE_DIR"

# 写入 .env（如果推送了）
if [ -f "/tmp/chillnote-api.env" ]; then
  echo "🔐 写入 $SHARED_ENV_FILE..."
  install -m 600 "/tmp/chillnote-api.env" "$SHARED_ENV_FILE"
  rm -f "/tmp/chillnote-api.env"
fi

# 首次迁移到 shared/.env 时，从当前发布目录复制现有配置。
if [ ! -f "$SHARED_ENV_FILE" ] && [ -f "$APP_DIR/.env" ]; then
  echo "ℹ️ 初始化 $SHARED_ENV_FILE（来源：$APP_DIR/.env）..."
  install -m 600 "$APP_DIR/.env" "$SHARED_ENV_FILE"
fi

if [ ! -f "$SHARED_ENV_FILE" ]; then
  echo "❌ 错误: 未检测到 $SHARED_ENV_FILE"
  exit 1
fi

echo "📦 解压代码..."
rm -rf "$APP_DIR/dist" "$APP_DIR/prisma"
tar -xzf /tmp/server-deploy.tar.gz -C "$APP_DIR"
rm /tmp/server-deploy.tar.gz

echo "🔐 将当前发布目录 .env 链接到共享环境文件..."
rm -f "$APP_DIR/.env"
ln -s "$SHARED_ENV_FILE" "$APP_DIR/.env"

cd "$APP_DIR"

echo "📥 安装生产依赖..."
export NODE_ENV=production
npm ci --omit=dev || npm install --omit=dev

echo "🔧 应用 Prisma 迁移并生成客户端..."
if [ -n "$RESOLVE_ROLLED_BACK" ]; then
  echo "🧯 预处理失败迁移记录: $RESOLVE_ROLLED_BACK"
  IFS=',' read -r -a MIGRATIONS <<< "$RESOLVE_ROLLED_BACK"
  for migration in "${MIGRATIONS[@]}"; do
    migration="$(echo "$migration" | xargs)"
    [ -z "$migration" ] && continue
    npx prisma migrate resolve --rolled-back "$migration" || true
  done
fi
npx prisma migrate deploy
npx prisma generate
# npx prisma db push --accept-data-loss

if ! command -v pm2 &> /dev/null; then
    echo "📥 安装 PM2..."
    npm install -g pm2
fi

echo "🚀 重启应用..."
# 停止旧进程（ID 0 是 chillnote，以及我们之前误创建的 chillnote-api）
pm2 delete chillnote 2>/dev/null || true
pm2 delete chillnote-api 2>/dev/null || true

# 启动新进程（名字现在是 chillnote）
pm2 start "$APP_DIR/ecosystem.config.cjs" --only chillnote --update-env
pm2 save

echo "🩺 健康检查..."
sleep 2
curl -fsS "http://127.0.0.1:4000/health" >/dev/null

echo "✅ 部署完成！"
ENDSSH

# 5. 清理本地临时文件
echo "🧹 清理临时文件..."
rm -f server-deploy.tar.gz
