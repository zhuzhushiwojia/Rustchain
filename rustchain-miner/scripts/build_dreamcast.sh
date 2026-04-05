#!/bin/bash
# SH-4 (Sega Dreamcast) Cross-Compilation Build Script for RustChain Miner
# 
# This script builds the RustChain miner for SH-4 (Hitachi SH7750R/SH7751R)
# architectures found in Sega Dreamcast and other retro hardware.
#
# Usage:
#   ./build_dreamcast.sh [OPTIONS]
#
# Options:
#   --release       Build in release mode
#   --clean         Clean before building
#   --test          Run tests after building
#   --docker        Use Docker-based build environment
#   --help          Show this help message

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default options
RELEASE=false
CLEAN=false
TEST=false
DOCKER=false

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MINER_DIR="$(dirname "$SCRIPT_DIR")"

# Target
TARGET="sh4-unknown-linux-gnu"
TARGET_NAME="Sega Dreamcast (SH-4)"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --release)
            RELEASE=true
            shift
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --test)
            TEST=true
            shift
            ;;
        --docker)
            DOCKER=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --release       Build in release mode"
            echo "  --clean         Clean before building"
            echo "  --test          Run tests after building"
            echo "  --docker        Use Docker-based build environment"
            echo "  --help          Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  RustChain Miner Dreamcast Build${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}Target:${NC} $TARGET_NAME"
echo -e "${GREEN}Release:${NC} $RELEASE"
echo -e "${GREEN}Clean:${NC} $CLEAN"
echo -e "${GREEN}Test:${NC} $TEST"
echo -e "${GREEN}Docker:${NC} $DOCKER"
echo ""

# Function to check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    
    # Check for Rust
    if ! command -v rustc &> /dev/null; then
        echo -e "${RED}Error: Rust is not installed${NC}"
        echo "Install from: https://rustup.rs/"
        exit 1
    fi
    
    # Check for cross tool (optional)
    if ! command -v cross &> /dev/null; then
        echo -e "${YELLOW}Warning: 'cross' is not installed. Using cargo directly...${NC}"
    fi
    
    # Check for Docker if using Docker build
    if [ "$DOCKER" = true ]; then
        if ! command -v docker &> /dev/null; then
            echo -e "${RED}Error: Docker is not installed${NC}"
            exit 1
        fi
    fi
    
    # Check for SH-4 toolchain (only for native builds)
    if [ "$DOCKER" = false ]; then
        if ! command -v sh4-linux-gnu-gcc &> /dev/null; then
            echo -e "${YELLOW}SH-4 toolchain not found. Attempting to install...${NC}"
            
            # Detect OS
            if [[ "$OSTYPE" == "linux-gnu"* ]]; then
                if command -v apt-get &> /dev/null; then
                    sudo apt-get update
                    sudo apt-get install -y gcc-sh4-linux-gnu g++-sh4-linux-gnu || \
                    sudo apt-get install -y gcc-4.8-sh4-linux-gnu g++-4.8-sh4-linux-gnu || \
                    echo -e "${YELLOW}SH-4 toolchain not available in apt. Use --docker option.${NC}"
                elif command -v dnf &> /dev/null; then
                    sudo dnf install -y gcc-sh4-linux-gnu g++-sh4-linux-gnu || \
                    echo -e "${YELLOW}SH-4 toolchain not available in dnf. Use --docker option.${NC}"
                fi
            elif [[ "$OSTYPE" == "darwin"* ]]; then
                echo -e "${RED}Native SH-4 cross-compile not supported on macOS${NC}"
                echo "Use --docker option for Docker-based build"
                exit 1
            fi
        fi
    fi
    
    echo -e "${GREEN}✓ Prerequisites check passed${NC}"
    echo ""
}

# Function to clean build artifacts
clean_build() {
    echo -e "${YELLOW}Cleaning build artifacts...${NC}"
    cd "$MINER_DIR"
    cargo clean
    rm -rf target/$TARGET
    echo -e "${GREEN}✓ Clean complete${NC}"
    echo ""
}

# Function to run tests
run_tests() {
    echo -e "${YELLOW}Running tests...${NC}"
    cd "$MINER_DIR"
    
    if [ "$DOCKER" = true ]; then
        cross test --target $TARGET
    else
        cargo test --target $TARGET
    fi
    
    echo -e "${GREEN}✓ Tests complete${NC}"
    echo ""
}

# Function to build with Docker
build_docker() {
    echo -e "${YELLOW}Building with Docker...${NC}"
    
    # Create Dockerfile for SH-4 build
    DOCKERFILE_CONTENT=$(cat <<'EOF'
FROM ubuntu:22.04

# Install SH-4 toolchain and dependencies
RUN apt-get update && apt-get install -y \
    gcc-sh4-linux-gnu \
    g++-sh4-linux-gnu \
    libc6-dev-sh4-cross \
    pkg-config \
    libssl-dev \
    openssl \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

ENV PATH="/root/.cargo/bin:${PATH}"
ENV CARGO_TARGET_SH4_UNKNOWN_LINUX_GNU_LINKER=sh4-linux-gnu-gcc

WORKDIR /workspace
EOF
)
    
    echo "$DOCKERFILE_CONTENT" > "$MINER_DIR/Dockerfile.dreamcast"
    
    # Build Docker image
    docker build -t rustchain-dreamcast-builder -f "$MINER_DIR/Dockerfile.dreamcast" "$MINER_DIR"
    
    # Run build in container
    docker run --rm \
        -v "$MINER_DIR":/workspace \
        -w /workspace \
        -e CARGO_TARGET_SH4_UNKNOWN_LINUX_GNU_LINKER=sh4-linux-gnu-gcc \
        rustchain-dreamcast-builder \
        cargo build --target $TARGET $( [ "$RELEASE" = true ] && echo "--release" )
    
    # Cleanup
    rm "$MINER_DIR/Dockerfile.dreamcast"
    
    echo -e "${GREEN}✓ Docker build complete${NC}"
    echo ""
}

# Function to build natively
build_native() {
    echo -e "${YELLOW}Building natively...${NC}"
    cd "$MINER_DIR"
    
    # Set environment variables for cross-compilation
    export CARGO_TARGET_SH4_UNKNOWN_LINUX_GNU_LINKER=sh4-linux-gnu-gcc
    export PKG_CONFIG_ALLOW_CROSS=1
    
    # Try to detect OpenSSL paths
    if [ -d "/usr/include/openssl" ]; then
        export OPENSSL_INCLUDE_DIR=/usr/include
    fi
    if [ -d "/usr/lib/sh4-linux-gnu" ]; then
        export OPENSSL_LIB_DIR=/usr/lib/sh4-linux-gnu
    fi
    
    if [ "$RELEASE" = true ]; then
        cargo build --target $TARGET --release
    else
        cargo build --target $TARGET
    fi
    
    echo -e "${GREEN}✓ Native build complete${NC}"
    echo ""
}

# Function to display build results
show_results() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Build Results${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    if [ "$RELEASE" = true ]; then
        BINARY_PATH="$MINER_DIR/target/$TARGET/release/rustchain-miner"
    else
        BINARY_PATH="$MINER_DIR/target/$TARGET/debug/rustchain-miner"
    fi
    
    if [ -f "$BINARY_PATH" ]; then
        echo -e "${GREEN}✓ Binary created:${NC} $BINARY_PATH"
        echo ""
        
        # Show binary info
        echo -e "${YELLOW}Binary Information:${NC}"
        file "$BINARY_PATH" || true
        echo ""
        
        # Show binary size
        ls -lh "$BINARY_PATH" | awk '{print "Size: " $5}'
        
        # Try to show architecture (if readelf is available)
        if command -v readelf &> /dev/null; then
            echo ""
            echo -e "${YELLOW}Architecture:${NC}"
            readelf -h "$BINARY_PATH" 2>/dev/null | grep -E "Machine|Class" || true
        fi
    else
        echo -e "${RED}✗ Build failed - binary not found${NC}"
        exit 1
    fi
    
    echo ""
}

# Main build process
main() {
    check_prerequisites
    
    if [ "$CLEAN" = true ]; then
        clean_build
    fi
    
    if [ "$TEST" = true ]; then
        run_tests
    fi
    
    if [ "$DOCKER" = true ]; then
        build_docker
    else
        build_native
    fi
    
    show_results
    
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Dreamcast Build Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "To deploy to Dreamcast:"
    echo -e "  1. Copy binary to your Dreamcast running Linux"
    echo -e "  2. Set executable: ${YELLOW}chmod +x rustchain-miner${NC}"
    echo -e "  3. Run: ${YELLOW}./rustchain-miner --wallet YOUR_WALLET --node https://your-node${NC}"
    echo ""
    echo -e "Note: Dreamcast SH-4 CPU runs at ~200MHz with limited memory"
    echo -e "Mining may be slow but earns bonus antiquity multiplier!"
    echo ""
}

main