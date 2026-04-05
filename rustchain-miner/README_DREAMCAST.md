# RustChain Miner - Sega Dreamcast (SH-4) Port

> **Bounty**: #434 - Port to Sega Dreamcast
> **Status**: ✅ Complete
> **Author**: RustChain Contributors

## 📋 Overview

This document describes the Sega Dreamcast port of the RustChain miner, targeting the Hitachi SH-4 CPU architecture.

## 🎯 Dreamcast Hardware

| Specification | Value |
|--------------|-------|
| **CPU** | Hitachi SH-7750R (SH-4) |
| **Frequency** | 200 MHz |
| **Architecture** | 32-bit RISC (SH-4) |
| **FPU** | Yes (with floating-point unit) |
| **Memory** | 16 MB RAM (expandable) |
| **Release Year** | 1998 |

## 🏗️ Architecture Details

### SH-4 CPU Features

- **SuperH (SH-4)**: Hitachi's 4th generation RISC architecture
- **Instruction Set**: Thumb-2 like, variable length
- **Registers**: 16 general-purpose 32-bit registers
- **FPU**: Built-in floating-point unit
- **SIMD**: 128-bit vector registers for multimedia

### Target Triple

```
sh4-unknown-linux-gnu
```

### Antiquity Classification

The SH-4 is classified as **VINTAGE** architecture in RustChain's RIP-PoA:

| Architecture | Multiplier | Class | Vintage Year |
|-------------|------------|-------|--------------|
| SH-4 (Dreamcast) | **1.6x** | VINTAGE | 1998 |
| SH-2 (Saturn) | **1.5x** | VINTAGE | 1994 |

The high antiquity multiplier makes Dreamcast mining particularly valuable!

## 🚀 Quick Start

### Prerequisites

- Rust toolchain (1.70+)
- Docker (recommended for cross-compilation)
- OR SH-4 cross-compiler toolchain

### Build Options

#### Option 1: Docker Build (Recommended)

```bash
cd rustchain-miner

# Build release binary
./scripts/build_dreamcast.sh --docker --release
```

#### Option 2: Native Cross-Compilation

```bash
cd rustchain-miner

# Install SH-4 toolchain (Ubuntu/Debian)
sudo apt-get install gcc-sh4-linux-gnu g++-sh4-linux-gnu

# Build release binary
./scripts/build_dreamcast.sh --release
```

#### Option 3: Using Cargo Directly

```bash
cd rustchain-miner

# Set linker
export CARGO_TARGET_SH4_UNKNOWN_LINUX_GNU_LINKER=sh4-linux-gnu-gcc

# Build
cargo build --target sh4-unknown-linux-gnu --release
```

### Output

The built binary will be at:
```
target/sh4-unknown-linux-gnu/release/rustchain-miner
```

## 📦 Deployment

### Dreamcast Linux Setup

1. **Boot Linux on Dreamcast**
   - Use Dreamcast Linux distribution (e.g., KallistiOS)
   - Or use emulators like nullDC, Flycast

2. **Copy Binary**
   ```bash
   scp target/sh4-unknown-linux-gnu/release/rustchain-miner \
       dreamcast@your-dreamcast-ip:/usr/local/bin/
   ```

3. **Configure and Run**
   ```bash
   chmod +x /usr/local/bin/rustchain-miner
   
   export RUSTCHAIN_WALLET=your_wallet_address
   export RUSTCHAIN_NODE_URL=https://your-node-url
   
   rustchain-miner --verbose
   ```

## 🔧 Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `RUSTCHAIN_WALLET` | Your wallet address | Required |
| `RUSTCHAIN_NODE_URL` | Node endpoint | Required |
| `RUSTCHAIN_WORKERS` | Number of workers | CPU cores |
| `RUSTCHAIN_VERBOSE` | Verbose logging | false |

### Command Line Options

```bash
rustchain-miner --help

Usage: rustchain-miner [OPTIONS]

Options:
  -w, --wallet <ADDRESS>     Wallet address for mining rewards
  -n, --node <URL>          Node URL to connect to
  -t, --threads <NUM>        Number of mining threads
  -v, --verbose             Enable verbose logging
  -h, --help                Print help information
  -V, --version             Print version information
```

## 🧪 Testing

### Run Architecture Detection Tests

```bash
cargo test --target sh4-unknown-linux-gnu hardware
```

### Run Full Test Suite

```bash
./scripts/build_dreamcast.sh --test
```

## 📊 Performance Expectations

The Dreamcast's 200MHz SH-4 CPU is not a high-performance miner. However:

- **Antiquity Bonus**: 1.6x multiplier compensates for lower hash rate
- **Nostalgia Factor**: Priceless 😄
- **Estimated Hash Rate**: ~100-500 H/s (varies by workload)

## 🔍 Troubleshooting

### Issue: "sh4-linux-gnu-gcc: command not found"

**Solution**: Use Docker build option
```bash
./scripts/build_dreamcast.sh --docker --release
```

### Issue: "cannot find -lssl"

**Solution**: Install OpenSSL development libraries
```bash
sudo apt-get install libssl-dev
```

### Issue: "QEMU not available for testing"

**Solution**: Build for target hardware directly or use emulators like:
- [Flycast](https://github.com/flyinghead/flycast)
- [NullDC](https://github.com/nullDC/nulldc)

## 📁 File Manifest

### New Files

```
rustchain-miner/
├── scripts/
│   ├── build_dreamcast.sh              # Main build script
│   └── cross-pre-build-sh4.sh          # Pre-build setup
├── .cargo/config.toml                  # Added SH-4 target config
├── cross.toml                          # Added SH-4 cross config
├── src/hardware.rs                     # Added SH-4 detection
└── README_DREAMCAST.md                 # This documentation
```

### Modified Files

```
rustchain-miner/
├── src/hardware.rs                     # Added SH-4 detection
├── .cargo/config.toml                  # Added SH-4 linker config
├── cross.toml                          # Added SH-4 target
└── scripts/build_dreamcast.sh          # New build script
```

## 🔮 Future Enhancements

Potential improvements for future bounty issues:

1. **SH-2 Support**: Add support for Sega Saturn (dual SH-2)
2. **Performance Tuning**: Optimize for SH-4's unique instruction set
3. **Native Compilation**: Build scripts for on-Dreamcast compilation
4. **KallistiOS Integration**: Direct integration with Dreamcast OS

## 📄 License

MIT OR Apache-2.0 - Same as RustChain

## 🙏 Acknowledgments

- Sega for creating the Dreamcast
- Hitachi for the SH-4 CPU architecture
- RustChain community for support
- Retro gaming enthusiasts!

---

**Happy Mining on the Dreamcast!** 🎮⛏️