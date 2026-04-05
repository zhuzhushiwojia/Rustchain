#!/bin/bash
# Cross-pre-build script for SH-4 (Sega Dreamcast)
# This script runs before cross-compilation to set up the environment

set -euo pipefail

echo "Setting up SH-4 cross-compilation environment..."

# Install SH-4 toolchain
install_sh4_toolchain() {
    echo "Installing SH-4 toolchain..."
    
    if command -v apt-get &> /dev/null; then
        # Try multiple possible package names
        apt-get update || true
        
        if apt-cache show gcc-sh4-linux-gnu &> /dev/null; then
            apt-get install -y gcc-sh4-linux-gnu g++-sh4-linux-gnu libc6-dev-sh4-cross
        elif apt-cache show gcc-4.8-sh4-linux-gnu &> /dev/null; then
            apt-get install -y gcc-4.8-sh4-linux-gnu g++-4.8-sh4-linux-gnu
        else
            echo "Warning: SH-4 toolchain not found in apt repositories"
            echo "Using Docker-based build recommended"
        fi
    elif command -v dnf &> /dev/null; then
        dnf install -y gcc-sh4-linux-gnu || echo "Warning: SH-4 toolchain not found"
    elif command -v pacman &> /dev/null; then
        pacman -S --noconfirm gcc-sh4-linux-gnu || echo "Warning: SH-4 toolchain not found"
    fi
}

# Verify toolchain
verify_toolchain() {
    if command -v sh4-linux-gnu-gcc &> /dev/null; then
        echo "SH-4 toolchain found: $(sh4-linux-gnu-gcc --version | head -1)"
    else
        echo "Warning: sh4-linux-gnu-gcc not found in PATH"
    fi
}

# Main
install_sh4_toolchain
verify_toolchain

echo "SH-4 pre-build setup complete!"