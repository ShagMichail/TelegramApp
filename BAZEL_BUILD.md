# Telegram iOS - Bazel Build Guide

This guide explains how to build and run Telegram iOS using Bazel without Xcode project generation.

## Prerequisites

### Required Software

| Software | Version | Installation |
|----------|---------|--------------|
| Xcode | 26.2 | [Apple Developer](https://developer.apple.com/download/) |
| Bazel | 8.4.2 | Auto-installed via Bazelisk |
| macOS | 26.x | - |
| Swift | 6.2.3 | Included with Xcode |
| CMake | Latest | `brew install cmake` |

### Verify Installation

```bash
# Check Xcode version
xcodebuild -version

# Check Bazel (will auto-download correct version via Bazelisk)
bazel --version

# Verify command line tools
xcode-select -p
```

## Quick Start

### 1. Clone the Repository

```bash
git clone --recursive -j8 https://github.com/ShagMichail/TelegramApp.git
cd TelegramApp
```

### 2. Build for Simulator

```bash
bazel build //Telegram:Telegram \
  --//Telegram:disableProvisioningProfiles=true \
  --cpu=ios_sim_arm64 \
  --define=buildNumber=100001 \
  --define=telegramVersion=12.2.2
```

### 3. Install on Simulator

```bash
# List available simulators
xcrun simctl list devices available

# Install on booted simulator
xcrun simctl install booted bazel-bin/Telegram/Telegram.ipa

# Or install on specific simulator by UUID
xcrun simctl install <SIMULATOR_UUID> bazel-bin/Telegram/Telegram.ipa
```

### 4. Launch the App

```bash
xcrun simctl launch booted ph.telegra.Telegraph
```

## Build Configuration

### Build Flags

| Flag | Description | Default |
|------|-------------|---------|
| `--//Telegram:disableProvisioningProfiles=true` | Disable code signing (for simulator) | `false` |
| `--cpu=ios_sim_arm64` | Build for ARM64 simulator | - |
| `--cpu=ios_arm64` | Build for ARM64 device | - |
| `--define=buildNumber=...` | Build number | Required |
| `--define=telegramVersion=...` | App version | Required |

### Build Variants

#### Debug Build (Simulator)

```bash
bazel build //Telegram:Telegram \
  --compilation_mode=dbg \
  --//Telegram:disableProvisioningProfiles=true \
  --cpu=ios_sim_arm64 \
  --define=buildNumber=100001 \
  --define=telegramVersion=12.2.2
```

#### Release Build (Device)

Requires code signing setup:

```bash
bazel build //Telegram:Telegram \
  --compilation_mode=opt \
  --cpu=ios_arm64 \
  --define=buildNumber=100001 \
  --define=telegramVersion=12.2.2
```

## Configuration Files

### Required Files

The following files must exist for the build to work:

1. **`.bazelversion`** - Specifies Bazel version (8.4.2)
2. **`MODULE.bazel`** - Bazel module dependencies
3. **`build-input/configuration-repository/`** - Build configuration (not tracked in git)

### Local Configuration Setup

Create `build-input/configuration-repository/` directory:

```bash
mkdir -p build-input/configuration-repository

# Copy example configuration
cp -r build-system/example-configuration/* build-input/configuration-repository/

# Create MODULE.bazel
cat > build-input/configuration-repository/MODULE.bazel << 'EOF'
module(
    name = "build_configuration",
    version = "1.0.0",
)
EOF

# Edit variables.bzl with your configuration
# See: build-system/template_minimal_development_configuration.json
```

### variables.bzl Configuration

Edit `build-input/configuration-repository/variables.bzl`:

```python
telegram_bundle_id = "org.your.bundle.id.Telegram"
telegram_api_id = "YOUR_API_ID"
telegram_api_hash = "YOUR_API_HASH"
telegram_team_id = "YOUR_TEAM_ID"
telegram_bazel_path = "bazel"
telegram_use_xcode_managed_codesigning = False
telegram_icloud_environment = "production"
# ... other settings
```

Get API credentials at: https://my.telegram.org/apps

## Troubleshooting

### Bazel Version Mismatch

If you see version errors, ensure Bazelisk is installed:

```bash
brew install bazelisk
```

Bazelisk will automatically use the version specified in `.bazelversion`.

### Missing Configuration

Error: `file '@build_configuration//:variables.bzl' does not contain symbol`

Solution: Ensure `build-input/configuration-repository/variables.bzl` contains all required variables.

### Build Fails with "no such target"

Run:
```bash
bazel clean --expunge
bazel build //Telegram:Telegram ...
```

### Simulator Not Found

List available simulators:
```bash
xcrun simctl list devices available
```

Boot a simulator:
```bash
xcrun simctl boot "iPhone 16"
```

## Useful Commands

```bash
# Clean build cache
bazel clean

# Clean everything (including downloaded tools)
bazel clean --expunge

# Query targets
bazel query '//Telegram:*'

# Build with verbose output
bazel build //Telegram:Telegram --verbose_failures

# Install on specific simulator
xcrun simctl install <UUID> bazel-bin/Telegram/Telegram.ipa

# Uninstall app
xcrun simctl uninstall booted ph.telegra.Telegraph

# List installed apps
xcrun simctl listapps booted
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Build Telegram iOS

on: [push, pull_request]

jobs:
  build:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive
      
      - name: Install Bazelisk
        run: brew install bazelisk
      
      - name: Setup configuration
        run: |
          mkdir -p build-input/configuration-repository
          cp -r build-system/example-configuration/* build-input/configuration-repository/
          # Add your configuration...
      
      - name: Build for Simulator
        run: |
          bazel build //Telegram:Telegram \
            --//Telegram:disableProvisioningProfiles=true \
            --cpu=ios_sim_arm64 \
            --define=buildNumber=${{ github.run_number }} \
            --define=telegramVersion=12.2.2
      
      - name: Upload IPA
        uses: actions/upload-artifact@v4
        with:
          name: Telegram.ipa
          path: bazel-bin/Telegram/Telegram.ipa
```

## Additional Resources

- [Bazel Documentation](https://bazel.build/)
- [rules_apple](https://github.com/bazelbuild/rules_apple)
- [rules_swift](https://github.com/bazelbuild/rules_swift)
- [Telegram API](https://core.telegram.org/api)
