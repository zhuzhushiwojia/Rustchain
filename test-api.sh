#!/bin/bash
# Rent-a-Relic Market - API 测试脚本
# RustChain Bounty #2312

BASE_URL="${BASE_URL:-http://localhost}"
TOKEN=""

echo "========================================="
echo "Rent-a-Relic Market API 测试"
echo "========================================="

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 测试函数
test_api() {
    local name=$1
    local method=$2
    local endpoint=$3
    local data=$4
    
    echo -e "\n${YELLOW}测试：${name}${NC}"
    
    if [ -n "$data" ]; then
        response=$(curl -s -w "\n%{http_code}" -X "$method" "$BASE_URL$endpoint" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $TOKEN" \
            -d "$data")
    else
        response=$(curl -s -w "\n%{http_code}" -X "$method" "$BASE_URL$endpoint" \
            -H "Authorization: Bearer $TOKEN")
    fi
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
        echo -e "${GREEN}✓ 成功 (HTTP $http_code)${NC}"
        echo "$body" | jq . 2>/dev/null || echo "$body"
    else
        echo -e "${RED}✗ 失败 (HTTP $http_code)${NC}"
        echo "$body"
    fi
    
    return $http_code
}

# 1. 健康检查
echo -e "\n=== 1. 健康检查 ==="
test_api "健康检查" "GET" "/health"

# 2. 获取统计数据
echo -e "\n=== 2. 平台统计 ==="
test_api "获取统计数据" "GET" "/api/stats"

# 3. 获取物品列表
echo -e "\n=== 3. 物品列表 ==="
test_api "获取物品列表" "GET" "/api/relics"

# 4. 获取单个物品
echo -e "\n=== 4. 单个物品 ==="
test_api "获取物品 #1" "GET" "/api/relics/1"

# 5. 用户注册
echo -e "\n=== 5. 用户注册 ==="
test_api "注册测试用户" "POST" "/api/auth/register" \
    '{"username":"test_user_'$$'","email":"test'$$$'@example.com","password":"test123"}'

# 6. 用户登录
echo -e "\n=== 6. 用户登录 ==="
login_response=$(curl -s -X POST "$BASE_URL/api/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"username":"ancient_collector","password":"password123"}')

TOKEN=$(echo "$login_response" | jq -r '.token' 2>/dev/null)

if [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
    echo -e "${GREEN}✓ 登录成功，Token 已获取${NC}"
    echo "Token: ${TOKEN:0:20}..."
else
    echo -e "${RED}✗ 登录失败${NC}"
    echo "$login_response"
fi

# 7. 获取用户信息
echo -e "\n=== 7. 用户信息 ==="
test_api "获取当前用户" "GET" "/api/users/me"

# 8. 创建新物品
echo -e "\n=== 8. 创建物品 ==="
create_response=$(curl -s -X POST "$BASE_URL/api/relics" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{
        "name": "Test Relic - Golden Coin",
        "description": "A test golden coin from ancient times",
        "category": "Ancient Artifacts",
        "daily_rate": 25.00,
        "deposit_amount": 250.00,
        "condition": "excellent"
    }')

echo "$create_response" | jq . 2>/dev/null || echo "$create_response"
relic_id=$(echo "$create_response" | jq -r '.relic.id' 2>/dev/null)

if [ -n "$relic_id" ] && [ "$relic_id" != "null" ]; then
    echo -e "${GREEN}✓ 物品创建成功，ID: $relic_id${NC}"
else
    echo -e "${YELLOW}⚠ 物品可能已存在或使用默认物品测试${NC}"
    relic_id=1
fi

# 9. 预订物品
echo -e "\n=== 9. 预订物品 ==="
test_api "预订物品 #$relic_id" "POST" "/api/relics/$relic_id/rent" \
    '{"start_date":"2026-04-01","end_date":"2026-04-07"}'

# 10. 获取租赁记录
echo -e "\n=== 10. 租赁记录 ==="
test_api "获取我的租赁" "GET" "/api/rentals?type=renting"

# 11. 按分类筛选
echo -e "\n=== 11. 分类筛选 ==="
test_api "筛选古代文物" "GET" "/api/relics?category=Ancient%20Artifacts"

# 12. 按状态筛选
echo -e "\n=== 12. 状态筛选 ==="
test_api "筛选可用物品" "GET" "/api/relics?status=available"

echo -e "\n========================================="
echo -e "${GREEN}所有测试完成！${NC}"
echo "========================================="
