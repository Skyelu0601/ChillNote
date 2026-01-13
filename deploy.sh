#!/bin/bash

# ChillNote 后端自动化部署脚本
# 使用方法: ./deploy.sh

set -euo pipefail  # 遇到错误立即退出

# ============ 配置区域 ============
SERVER_IP="45.43.57.244"
SERVER_USER="root"
REMOTE_DIR="/root/chillnote-api"
LOCAL_SERVER_DIR="./server"

echo "🚀 开始部署 ChillNote 后端..."

# 1. 检查本地环境
echo "📦 检查本地文件..."
if [ ! -d "$LOCAL_SERVER_DIR" ]; then
    echo "❌ 错误: 找不到 server 目录"
    exit 1
fi

# 2. 本地构建（避免服务器 Node 版本过低导致 devDependencies/tsc 安装失败）
echo "🔨 本地编译 TypeScript..."
pushd "$LOCAL_SERVER_DIR" >/dev/null
npm install
npm run build
popd >/dev/null

# 2. 打包代码
echo "📦 打包后端代码..."
cd "$LOCAL_SERVER_DIR"
tar -czf ../server-deploy.tar.gz \
    --exclude='node_modules' \
    --exclude='uploads' \
    src/ \
    dist/ \
    prisma/ \
    ecosystem.config.cjs \
    package.json \
    package-lock.json \
    tsconfig.json

cd ..

# 3. 上传到服务器
echo "📤 上传代码到服务器..."
scp server-deploy.tar.gz ${SERVER_USER}@${SERVER_IP}:/tmp/

# 4. 在服务器上执行部署（releases + current 原子切换）
echo "🔧 在服务器上安装和启动..."
ssh ${SERVER_USER}@${SERVER_IP} << 'ENDSSH'
set -euo pipefail

BASE_DIR="/root/chillnote-api"
RELEASES_DIR="$BASE_DIR/releases"
CURRENT_LINK="$BASE_DIR/current"
KEEP_RELEASES="${KEEP_RELEASES:-5}"

mkdir -p "$RELEASES_DIR"

if [ ! -f "$BASE_DIR/.env" ]; then
  echo "⚠️  警告: 未检测到 $BASE_DIR/.env（PM2 将无法读到 GEMINI_API_KEY 等配置）"
else
  # Prisma/Node CLI 不会自动读取 .env，这里显式导出给后续命令使用。
  set -a
  # shellcheck disable=SC1090
  source "$BASE_DIR/.env"
  set +a
  if [ -z "${DATABASE_URL:-}" ]; then
    echo "❌ 错误: $BASE_DIR/.env 中未配置 DATABASE_URL，Prisma 无法工作"
    exit 1
  fi
fi

RELEASE_ID="$(date +%Y%m%d%H%M%S)"
RELEASE_DIR="$RELEASES_DIR/$RELEASE_ID"
mkdir -p "$RELEASE_DIR"
cd "$RELEASE_DIR"

# 解压代码
echo "📦 解压代码..."
tar -xzf /tmp/server-deploy.tar.gz -C "$RELEASE_DIR"
rm /tmp/server-deploy.tar.gz

# 检查并安装/升级 Node.js（需要 >= 18）
# 说明：当前服务器为 CentOS 7，无法通过 yum 安装 Node 18（glibc 版本过低）。
# 本脚本采用“本地编译 dist + 服务器仅安装生产依赖”的策略，允许继续使用 Node 16。
if ! command -v node &> /dev/null; then
    echo "❌ 错误: 服务器未安装 Node.js"
    exit 1
fi

echo "Node.js 版本: $(node -v)"
echo "NPM 版本: $(npm -v)"

# 安装依赖
echo "📥 安装生产依赖..."
export NODE_ENV=production
# npm@8 在部分场景下对 --omit=dev 的 lockfile 处理不够稳定，这里直接用 production 安装策略
npm ci --only=production || npm install --only=production

# 生成 Prisma 客户端
echo "🔧 生成 Prisma 客户端..."
npx prisma generate

# 同步数据库结构
if [ -d "prisma/migrations" ] && [ "$(find prisma/migrations -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" != "0" ]; then
  echo "🗄️ 执行 Prisma migrate deploy..."
  npx prisma migrate deploy
else
  echo "🗄️ 执行 Prisma db push..."
  npx prisma db push --accept-data-loss
fi

# 安装 PM2（如果没有）
if ! command -v pm2 &> /dev/null; then
    echo "📥 安装 PM2..."
    npm install -g pm2
fi

# 切换 current -> 新版本（原子化）
echo "🔁 切换 current 到新版本: $RELEASE_ID"
ln -sfn "$RELEASE_DIR" "$CURRENT_LINK"

# 启动（确保 script path 指向 current）
echo "🚀 重启应用（确保使用 current 版本）..."
pm2 delete chillnote-api 2>/dev/null || true
pm2 start "$CURRENT_LINK/ecosystem.config.cjs" --only chillnote-api --update-env

# 设置开机自启
pm2 startup systemd -u root --hp /root 2>/dev/null || true
pm2 save

# 显示状态
pm2 list

# 本机健康检查（避免 DNS/反代影响）
PORT="${PORT:-4000}"
echo "🔍 本机健康检查: http://127.0.0.1:${PORT}/health"
curl -fsSL "http://127.0.0.1:${PORT}/health" >/dev/null && echo "   ✅ OK" || echo "   ❌ FAIL"

echo "🔍 本机端点检查: http://127.0.0.1:${PORT}/ai/voice-note"
VOICE_HTTP=$(curl -s -o /dev/null -w "%{http_code}" -X POST "http://127.0.0.1:${PORT}/ai/voice-note" -H "Content-Type: application/json" -d '{}')
if [ "$VOICE_HTTP" = "400" ] || [ "$VOICE_HTTP" = "500" ]; then
  echo "   ✅ /ai/voice-note reachable (HTTP $VOICE_HTTP)"
else
  echo "   ⚠️  /ai/voice-note unexpected (HTTP $VOICE_HTTP)"
fi

# 清理旧版本
echo "🧹 清理旧 releases（保留最新 $KEEP_RELEASES 个）..."
ls -1dt "$RELEASES_DIR"/* 2>/dev/null | tail -n +$((KEEP_RELEASES + 1)) | xargs -r rm -rf

echo "✅ 部署完成！"
ENDSSH

# 5. 清理本地临时文件
echo "🧹 清理临时文件..."
rm server-deploy.tar.gz

# 6. 测试健康检查
echo "🔍 测试 API..."
sleep 3
curl -fsSL https://api.chillnoteai.com/health && echo "" || echo "⚠️ 健康检查失败，请检查日志"

echo ""
echo "✅ 部署完成！"
echo "📊 查看日志: ssh ${SERVER_USER}@${SERVER_IP} 'pm2 logs chillnote-api'"
echo "📈 查看状态: ssh ${SERVER_USER}@${SERVER_IP} 'pm2 status'"
