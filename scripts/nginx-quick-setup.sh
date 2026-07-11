#!/bin/bash
# Nginx 配置快速脚本
# 用途：自动配置 Nginx 以支持 ChillNote 大文件上传
# 使用方法：在服务器上执行 bash nginx-quick-setup.sh

set -e

echo "🚀 ChillNote Nginx 配置脚本"
echo "================================"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查是否为 root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ 请使用 root 用户运行此脚本${NC}"
    echo "   使用: sudo bash nginx-quick-setup.sh"
    exit 1
fi

# 检查 Nginx 是否安装
if ! command -v nginx &> /dev/null; then
    echo -e "${RED}❌ Nginx 未安装${NC}"
    echo ""
    echo "请先安装 Nginx:"
    echo "  CentOS/RHEL: yum install -y nginx"
    echo "  Ubuntu/Debian: apt install -y nginx"
    exit 1
fi

echo -e "${GREEN}✅ Nginx 已安装${NC}"
nginx -v
echo ""

# 查找配置文件
echo "🔍 查找 api.chillnoteai.com 的配置文件..."
CONFIG_FILE=""

# 搜索包含 api.chillnoteai.com 的配置
FOUND_FILES=$(grep -rl "api.chillnoteai.com" /etc/nginx/ 2>/dev/null || true)

if [ -z "$FOUND_FILES" ]; then
    echo -e "${YELLOW}⚠️  未找到 api.chillnoteai.com 的配置文件${NC}"
    echo ""
    echo "请手动指定配置文件路径，或者创建新配置文件。"
    echo "常见位置："
    echo "  - /etc/nginx/conf.d/api.chillnoteai.com.conf"
    echo "  - /etc/nginx/sites-available/api.chillnoteai.com"
    echo ""
    read -p "请输入配置文件路径（或按回车跳过）: " CONFIG_FILE
    
    if [ -z "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}⚠️  跳过自动配置${NC}"
        echo ""
        echo "请参考文档手动配置: docs/nginx-setup-guide.md"
        exit 0
    fi
else
    CONFIG_FILE=$(echo "$FOUND_FILES" | head -1)
    echo -e "${GREEN}✅ 找到配置文件: $CONFIG_FILE${NC}"
fi

# 检查配置文件是否存在
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}❌ 配置文件不存在: $CONFIG_FILE${NC}"
    exit 1
fi

# 备份配置文件
BACKUP_FILE="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
echo ""
echo "📦 备份配置文件..."
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo -e "${GREEN}✅ 备份完成: $BACKUP_FILE${NC}"

# 检查是否已经配置了 client_max_body_size
if grep -q "client_max_body_size" "$CONFIG_FILE"; then
    CURRENT_SIZE=$(grep "client_max_body_size" "$CONFIG_FILE" | head -1 | awk '{print $2}' | tr -d ';')
    echo ""
    echo -e "${YELLOW}⚠️  配置文件中已存在 client_max_body_size: $CURRENT_SIZE${NC}"
    echo ""
    read -p "是否要更新为 150m？(y/n): " UPDATE_CONFIRM
    
    if [ "$UPDATE_CONFIRM" != "y" ]; then
        echo "取消更新"
        exit 0
    fi
    
    # 更新现有配置
    sed -i.tmp "s/client_max_body_size.*;/client_max_body_size 150m;/" "$CONFIG_FILE"
    echo -e "${GREEN}✅ 已更新 client_max_body_size 为 150m${NC}"
else
    # 添加新配置
    echo ""
    echo "📝 添加上传限制配置..."
    
    # 在 server 块中添加配置
    # 这里使用简单的方法：在第一个 server { 后面添加
    sed -i.tmp '/server {/a\    # Upload limits for ChillNote voice recordings\n    client_max_body_size 150m;\n    client_body_buffer_size 128k;\n    client_body_timeout 300s;\n' "$CONFIG_FILE"
    
    echo -e "${GREEN}✅ 已添加 client_max_body_size 150m${NC}"
fi

# 检查是否有 proxy_read_timeout
if ! grep -q "proxy_read_timeout" "$CONFIG_FILE"; then
    echo "📝 添加 proxy 超时配置..."
    sed -i.tmp '/location \/ {/a\        # Proxy timeouts for long-running requests\n        proxy_connect_timeout 60s;\n        proxy_send_timeout 300s;\n        proxy_read_timeout 300s;\n' "$CONFIG_FILE"
    echo -e "${GREEN}✅ 已添加 proxy 超时配置${NC}"
fi

# 测试配置
echo ""
echo "🧪 测试 Nginx 配置..."
if nginx -t; then
    echo -e "${GREEN}✅ 配置测试通过${NC}"
else
    echo -e "${RED}❌ 配置测试失败${NC}"
    echo ""
    echo "正在恢复备份..."
    cp "$BACKUP_FILE" "$CONFIG_FILE"
    echo -e "${YELLOW}⚠️  已恢复原配置${NC}"
    exit 1
fi

# 重新加载 Nginx
echo ""
echo "🔄 重新加载 Nginx..."
if systemctl reload nginx; then
    echo -e "${GREEN}✅ Nginx 重新加载成功${NC}"
else
    echo -e "${RED}❌ Nginx 重新加载失败${NC}"
    echo ""
    echo "正在恢复备份..."
    cp "$BACKUP_FILE" "$CONFIG_FILE"
    systemctl reload nginx
    echo -e "${YELLOW}⚠️  已恢复原配置${NC}"
    exit 1
fi

# 验证配置
echo ""
echo "🔍 验证配置..."
echo "当前 client_max_body_size 配置："
nginx -T 2>/dev/null | grep "client_max_body_size" | head -5

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}✅ Nginx 配置完成！${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo "📋 配置摘要："
echo "  - 配置文件: $CONFIG_FILE"
echo "  - 备份文件: $BACKUP_FILE"
echo "  - 最大上传: 150MB"
echo "  - 超时时间: 300秒"
echo ""
echo "📝 下一步："
echo "  1. 更新应用配置: 在 .env 中设置 MAX_VOICE_NOTE_AUDIO_MB=100 和 AI_JSON_LIMIT=150mb"
echo "  2. 重启应用: pm2 restart chillnote-api"
echo "  3. 测试上传: curl https://api.chillnoteai.com/health"
echo ""
echo "📚 详细文档: docs/nginx-setup-guide.md"
