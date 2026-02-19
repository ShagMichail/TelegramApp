# 🚀 Quick Start - Build Telegram iOS with Bazel

## Prerequisites

```bash
# Install Xcode 26.2 from Apple Developer
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install CMake
brew install cmake
```

## Build & Run (5 minutes)

### 1. Clone

```bash
git clone --recursive -j8 https://github.com/ShagMichail/TelegramApp.git
cd TelegramApp
```

### 2. Setup Configuration

```bash
mkdir -p build-input/configuration-repository
cp -r build-system/example-configuration/* build-input/configuration-repository/

cat > build-input/configuration-repository/MODULE.bazel << 'EOF'
module(
    name = "build_configuration",
    version = "1.0.0",
)
EOF
```

### 3. Build

```bash
bazel build //Telegram:Telegram \
  --//Telegram:disableProvisioningProfiles=true \
  --cpu=ios_sim_arm64 \
  --define=buildNumber=100001 \
  --define=telegramVersion=12.2.2
```

### 4. Install & Run

```bash
# Boot simulator (if not running)
xcrun simctl boot "iPhone 16"

# Install app
xcrun simctl install booted bazel-bin/Telegram/Telegram.ipa

# Launch app
xcrun simctl launch booted ph.telegra.Telegraph
```

## 📚 Full Documentation

See [BAZEL_BUILD.md](BAZEL_BUILD.md) for detailed instructions, troubleshooting, and CI/CD setup.

## Common Commands

```bash
# Clean build
bazel clean

# Rebuild everything
bazel clean --expunge

# Check Bazel version
bazel --version  # Auto-uses 8.4.2 via Bazelisk
```

## Requirements

| Software | Version |
|----------|---------|
| Xcode | 26.2 |
| Bazel | 8.4.2 (via Bazelisk) |
| macOS | 26.x |
| CMake | Latest |
