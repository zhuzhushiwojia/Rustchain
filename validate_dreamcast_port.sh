#!/bin/bash
# Validation script for Sega Dreamcast (SH-4) port
# Bounty #434 - Port to Sega Dreamcast

set +euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Navigate to Rustchain root
cd "$SCRIPT_DIR"
MINER_DIR="$SCRIPT_DIR/rustchain-miner"

PASSED=0
FAILED=0

check() {
    local description="$1"
    local command="$2"
    
    echo -n "Checking: $description... "
    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC}"
        ((FAILED++))
    fi
}

check_file() {
    local description="$1"
    local file="$2"
    
    echo -n "Checking: $description... "
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC}"
        ((FAILED++))
    fi
}

check_executable() {
    local description="$1"
    local file="$2"
    
    echo -n "Checking: $description... "
    if [ -x "$file" ]; then
        echo -e "${GREEN}✓${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC}"
        ((FAILED++))
    fi
}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Dreamcast (SH-4) Port Validation${NC}"
echo -e "${BLUE}  Bounty #434${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${YELLOW}Checking build configuration...${NC}"
check_file "cross.toml exists" "$MINER_DIR/cross.toml"
check "SH-4 target in cross.toml" "grep -q 'sh4-unknown-linux-gnu' $MINER_DIR/cross.toml"
check_file ".cargo/config.toml exists" "$MINER_DIR/.cargo/config.toml"
check "SH-4 linker in .cargo/config.toml" "grep -q 'sh4-linux-gnu-gcc' $MINER_DIR/.cargo/config.toml"
check "SH-4 rustflags in .cargo/config.toml" "grep -q 'target-cpu=sh7750' $MINER_DIR/.cargo/config.toml"
check "build-dreamcast alias in .cargo/config.toml" "grep -q 'build-dreamcast' $MINER_DIR/.cargo/config.toml"
echo ""

echo -e "${YELLOW}Checking build scripts...${NC}"
check_file "build_dreamcast.sh exists" "$MINER_DIR/scripts/build_dreamcast.sh"
check_executable "build_dreamcast.sh is executable" "$MINER_DIR/scripts/build_dreamcast.sh"
check_file "cross-pre-build-sh4.sh exists" "$MINER_DIR/scripts/cross-pre-build-sh4.sh"
check_executable "cross-pre-build-sh4.sh is executable" "$MINER_DIR/scripts/cross-pre-build-sh4.sh"
echo ""

echo -e "${YELLOW}Checking hardware detection...${NC}"
check "SH-4 detection in hardware.rs" "grep -q 'SH-4' $MINER_DIR/src/hardware.rs"
check "SH-7750R detection" "grep -q 'sh7750' $MINER_DIR/src/hardware.rs"
check "Dreamcast detection" "grep -q 'Dreamcast' $MINER_DIR/src/hardware.rs"
echo ""

echo -e "${YELLOW}Checking test coverage...${NC}"
check_file "arch_tests.rs exists" "$MINER_DIR/src/arch_tests.rs"
check "SH-4 tests defined" "grep -q 'test_sh4' $MINER_DIR/src/arch_tests.rs"
check "Dreamcast detection test" "grep -q 'test_sh4_dreamcast_detection' $MINER_DIR/src/arch_tests.rs"
check "SH-4 wallet generation test" "grep -q 'test_sh4_wallet_generation' $MINER_DIR/src/arch_tests.rs"
check "SH-4 antiquity test" "grep -q 'test_sh4_antiquity_multiplier' $MINER_DIR/src/arch_tests.rs"
echo ""

echo -e "${YELLOW}Checking documentation...${NC}"
check_file "README_DREAMCAST.md exists" "$MINER_DIR/README_DREAMCAST.md"
check "Quick Start section" "grep -q 'Quick Start' $MINER_DIR/README_DREAMCAST.md"
check "Build Options section" "grep -q 'Build Options' $MINER_DIR/README_DREAMCAST.md"
check "Deployment section" "grep -q 'Deployment' $MINER_DIR/README_DREAMCAST.md"
check "Troubleshooting section" "grep -q 'Troubleshooting' $MINER_DIR/README_DREAMCAST.md"
check "SH-4 hardware specs" "grep -q 'SH-7750R' $MINER_DIR/README_DREAMCAST.md"
echo ""

echo -e "${YELLOW}Checking Cargo configuration...${NC}"
check_file "Cargo.toml exists" "$MINER_DIR/Cargo.toml"
check "arch_tests module in lib.rs" "grep -q 'mod arch_tests' $MINER_DIR/src/lib.rs"
echo ""

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Validation Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All validation tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some validation tests failed${NC}"
    exit 1
fi