#!/bin/bash

# ChillNote API 连接测试脚本
# 测试所有关键的 API 端点

set -e

API_BASE="https://api.chillnoteai.com"

echo "🧪 开始测试 ChillNote API 连接..."
echo "📍 API 地址: $API_BASE"
echo ""

# 测试 1: 健康检查
echo "1️⃣ 测试健康检查端点..."
HEALTH_RESPONSE=$(curl -s "$API_BASE/health")

if echo "$HEALTH_RESPONSE" | grep -q '{"ok":true}'; then
    echo "   ✅ 健康检查通过"
else
    echo "   ❌ 健康检查失败"
    echo "   响应: $HEALTH_RESPONSE"
    exit 1
fi

# 测试 2: HTTPS 证书
echo ""
echo "2️⃣ 测试 HTTPS 证书..."
CERT_INFO=$(curl -vI "$API_BASE/health" 2>&1 | grep -E "SSL certificate verify|subject:|issuer:")
if echo "$CERT_INFO" | grep -q "SSL certificate verify ok"; then
    echo "   ✅ SSL 证书有效"
else
    echo "   ⚠️  SSL 证书验证警告"
fi

# 测试 3: CORS 配置
echo ""
echo "3️⃣ 测试 CORS 配置..."
CORS_HEADER=$(curl -s -I "$API_BASE/health" | grep -i "access-control-allow-origin")
if [ -n "$CORS_HEADER" ]; then
    echo "   ✅ CORS 已配置: $CORS_HEADER"
else
    echo "   ⚠️  未检测到 CORS 头"
fi

# 测试 4: AI 端点（不需要认证）
echo ""
echo "4️⃣ 测试 AI 端点（Gemini）..."
AI_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API_BASE/ai/gemini" \
    -H "Content-Type: application/json" \
    -d '{"prompt":"测试","systemPrompt":"简短回复"}')

if [ "$AI_RESPONSE" = "200" ] || [ "$AI_RESPONSE" = "500" ]; then
    echo "   ✅ AI 端点可访问 (HTTP $AI_RESPONSE)"
    if [ "$AI_RESPONSE" = "500" ]; then
        echo "   ℹ️  提示: 可能需要在服务器配置 GEMINI_API_KEY"
    fi
else
    echo "   ❌ AI 端点失败 (HTTP $AI_RESPONSE)"
fi

echo ""
echo "4️⃣.1️⃣ 测试 AI 端点（Voice Note）..."
VOICE_NOTE_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API_BASE/ai/voice-note" \
    -H "Content-Type: application/json" \
    -d '{}')

if [ "$VOICE_NOTE_RESPONSE" = "400" ] || [ "$VOICE_NOTE_RESPONSE" = "500" ]; then
    echo "   ✅ Voice Note 端点可访问 (HTTP $VOICE_NOTE_RESPONSE)"
    if [ "$VOICE_NOTE_RESPONSE" = "500" ]; then
        echo "   ℹ️  提示: 可能需要在服务器配置 GEMINI_API_KEY"
    fi
elif [ "$VOICE_NOTE_RESPONSE" = "404" ]; then
    echo "   ⚠️  Voice Note 端点未部署 (HTTP 404) - App 会自动回退到 /ai/gemini"
else
    echo "   ❌ Voice Note 端点失败 (HTTP $VOICE_NOTE_RESPONSE)"
fi

# 测试 5: 响应时间
echo ""
echo "5️⃣ 测试响应时间..."
START_TIME=$(python3 -c 'import time; print(int(time.time() * 1000))')
curl -s "$API_BASE/health" > /dev/null
END_TIME=$(python3 -c 'import time; print(int(time.time() * 1000))')
RESPONSE_TIME=$((END_TIME - START_TIME))

if [ "$RESPONSE_TIME" -lt 1000 ]; then
    echo "   ✅ 响应时间: ${RESPONSE_TIME}ms (优秀)"
elif [ "$RESPONSE_TIME" -lt 3000 ]; then
    echo "   ✅ 响应时间: ${RESPONSE_TIME}ms (良好)"
else
    echo "   ⚠️  响应时间: ${RESPONSE_TIME}ms (较慢)"
fi

# 总结
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ API 连接测试完成！"
echo ""
echo "📱 iOS App 配置信息："
echo "   Backend URL: $API_BASE"
echo ""
echo "🔧 下一步："
echo "   1. 在 Xcode 中打开项目"
echo "   2. 运行 App（模拟器或真机）"
echo "   3. 检查 App 是否能正常连接到服务器"
echo ""
echo "📊 如需查看服务器日志："
echo "   ssh root@45.43.57.244 'pm2 logs chillnote-api'"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
