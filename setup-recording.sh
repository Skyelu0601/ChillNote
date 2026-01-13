#!/bin/bash

# ChillNote 录音功能快速配置脚本

echo "🎙️ ChillNote 录音功能配置向导"
echo "================================"
echo ""

# 检查是否在正确的目录
if [ ! -f "server/package.json" ]; then
    echo "❌ 错误: 请在 ChillNote 项目根目录运行此脚本"
    exit 1
fi

# 1. 询问 Gemini API 密钥
echo "📝 步骤 1: 配置 Gemini API 密钥"
echo ""
echo "请访问 https://makersuite.google.com/app/apikey 获取 API 密钥"
echo ""
read -p "请输入你的 Gemini API 密钥: " GEMINI_KEY

if [ -z "$GEMINI_KEY" ]; then
    echo "❌ API 密钥不能为空"
    exit 1
fi

# 2. 更新 server/.env
echo ""
echo "⚙️ 步骤 2: 更新后端配置..."
cd server

cat > .env << EOF
DATABASE_URL="file:./dev.db"
PORT=4000
JWT_SECRET="dev-secret-key-$(openssl rand -hex 16)"
GEMINI_API_KEY="$GEMINI_KEY"
EOF

echo "✅ 后端配置已更新"

# 3. 初始化数据库
echo ""
echo "🗄️ 步骤 3: 初始化数据库..."
npx prisma generate > /dev/null 2>&1
npx prisma db push --accept-data-loss > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "✅ 数据库初始化成功"
else
    echo "❌ 数据库初始化失败"
    exit 1
fi

# 4. 启动服务器
echo ""
echo "🚀 步骤 4: 启动后端服务器..."
echo ""
echo "服务器将在 http://192.168.1.6:4000 启动"
echo ""
echo "⚠️ 重要提醒:"
echo "1. 请在 Xcode 中配置环境变量 GEMINI_API_KEY"
echo "   路径: Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables"
echo ""
echo "2. 建议在真机上测试录音功能 (模拟器音频不稳定)"
echo ""
echo "3. 查看完整配置指南: docs/录音功能配置指南.md"
echo ""
echo "================================"
echo ""
read -p "按回车键启动服务器..."

npm run dev
