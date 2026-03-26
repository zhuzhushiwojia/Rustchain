#!/bin/bash
# RustChain Founding Miner - API Test Script
# Issue: #2451 (~75 RTC)

set -e

BASE_URL="${BASE_URL:-http://localhost:8080}"
TOKEN=""

echo "=========================================="
echo "RustChain Founding Miner - API Tests"
echo "Base URL: $BASE_URL"
echo "=========================================="
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
}

fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    exit 1
}

info() {
    echo -e "${YELLOW}→${NC} $1"
}

# Test 1: Health Check
info "Testing health check..."
RESPONSE=$(curl -s "$BASE_URL/api/health")
if echo "$RESPONSE" | grep -q '"status":"healthy"'; then
    pass "Health check passed"
else
    fail "Health check failed: $RESPONSE"
fi
echo ""

# Test 2: Register User 1
info "Registering user: founding_miner_1..."
RESPONSE=$(curl -s -X POST "$BASE_URL/api/register" \
    -H "Content-Type: application/json" \
    -d '{
        "username": "founding_miner_1",
        "password": "password123",
        "wallet_address": "RTC1TestWallet1Address123456789",
        "miner_name": "Test Miner Alpha"
    }')

if echo "$RESPONSE" | grep -q '"message":"Registration successful"'; then
    pass "User registration successful"
    TOKEN=$(echo "$RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    info "Token received: ${TOKEN:0:20}..."
else
    # Might already exist
    if echo "$RESPONSE" | grep -q "already exists"; then
        info "User already exists, logging in..."
        LOGIN_RESPONSE=$(curl -s -X POST "$BASE_URL/api/login" \
            -H "Content-Type: application/json" \
            -d '{"username": "founding_miner_1", "password": "password123"}')
        TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
        pass "Login successful"
    else
        fail "Registration failed: $RESPONSE"
    fi
fi
echo ""

# Test 3: Get Miner Stats
info "Testing miner stats..."
RESPONSE=$(curl -s "$BASE_URL/api/miner/stats" \
    -H "Authorization: Bearer $TOKEN")
if echo "$RESPONSE" | grep -q '"total_rewards"'; then
    pass "Miner stats retrieved"
    echo "Response: $RESPONSE" | head -c 200
    echo "..."
else
    fail "Miner stats failed: $RESPONSE"
fi
echo ""

# Test 4: Start Mining Session
info "Starting mining session..."
RESPONSE=$(curl -s -X POST "$BASE_URL/api/miner/sessions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{"miner_name": "Test Session 1"}')
if echo "$RESPONSE" | grep -q '"message":"Mining session started"'; then
    pass "Mining session started"
    SESSION_ID=$(echo "$RESPONSE" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
    info "Session ID: $SESSION_ID"
else
    fail "Start session failed: $RESPONSE"
fi
echo ""

# Test 5: End Mining Session
if [ -n "$SESSION_ID" ]; then
    info "Ending mining session $SESSION_ID..."
    RESPONSE=$(curl -s -X POST "$BASE_URL/api/miner/sessions/$SESSION_ID/end" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d '{"blocks_found": 3, "rewards_earned": 90.5}')
    if echo "$RESPONSE" | grep -q '"message":"Mining session ended"'; then
        pass "Mining session ended with rewards"
    else
        fail "End session failed: $RESPONSE"
    fi
    echo ""
fi

# Test 6: Get Rewards
info "Testing rewards history..."
RESPONSE=$(curl -s "$BASE_URL/api/rewards" \
    -H "Authorization: Bearer $TOKEN")
if echo "$RESPONSE" | grep -q '"rewards"'; then
    pass "Rewards history retrieved"
else
    fail "Rewards failed: $RESPONSE"
fi
echo ""

# Test 7: Get Leaderboard
info "Testing leaderboard..."
RESPONSE=$(curl -s "$BASE_URL/api/leaderboard?limit=10")
if echo "$RESPONSE" | grep -q '"leaderboard"'; then
    pass "Leaderboard retrieved"
else
    fail "Leaderboard failed: $RESPONSE"
fi
echo ""

# Test 8: Get Mining Sessions
info "Testing mining sessions..."
RESPONSE=$(curl -s "$BASE_URL/api/miner/sessions" \
    -H "Authorization: Bearer $TOKEN")
if echo "$RESPONSE" | grep -q '"sessions"'; then
    pass "Mining sessions retrieved"
else
    fail "Sessions failed: $RESPONSE"
fi
echo ""

# Test 9: Test Invalid Token
info "Testing authentication (invalid token)..."
RESPONSE=$(curl -s "$BASE_URL/api/miner/stats" \
    -H "Authorization: Bearer invalid_token")
if echo "$RESPONSE" | grep -q "Invalid token"; then
    pass "Invalid token rejected correctly"
else
    fail "Invalid token not rejected: $RESPONSE"
fi
echo ""

# Test 10: Test Missing Token
info "Testing authentication (missing token)..."
RESPONSE=$(curl -s "$BASE_URL/api/miner/stats")
if echo "$RESPONSE" | grep -q "Token is missing"; then
    pass "Missing token rejected correctly"
else
    fail "Missing token not rejected: $RESPONSE"
fi
echo ""

echo "=========================================="
echo -e "${GREEN}All tests completed successfully!${NC}"
echo "=========================================="
