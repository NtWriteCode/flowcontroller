#!/bin/bash

# Android PC Controller Build Script
# Builds release APK and creates server distribution packages
# This script is designed to run on Linux build servers

set -e  # Exit on any error

echo "🏗️  Flow Controller Build System (Linux)"
echo "=============================================="
echo

# Configuration
BUILD_DIR="build"
DIST_DIR="distributable"
VERSION=$(date +"%Y%m%d_%H%M%S")
APK_NAME="flow-controller-${VERSION}.apk"
BUILD_HOST=$(hostname)
BUILD_USER=$(whoami)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check Flutter
    if ! command_exists flutter; then
        print_error "Flutter not found. Please install Flutter first."
        exit 1
    fi
    
    # Check Python
    if ! command_exists python3; then
        print_error "Python3 not found. Please install Python 3.8+ first."
        exit 1
    fi
    
    # Check zip command
    if ! command_exists zip; then
        print_error "zip not found. Please install zip utility first."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Clean and create build directories
setup_build_dir() {
    print_status "Setting up build directories..."
    
    # Clean old build directories
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
    fi
    if [ -d "$DIST_DIR" ]; then
        rm -rf "$DIST_DIR"
    fi
    
    # Create working build directories
    mkdir -p "$BUILD_DIR"/{android,server-windows,server-linux,server-common}
    
    # Create distributable directory
    mkdir -p "$DIST_DIR"
    
    print_success "Build directories created: $BUILD_DIR and $DIST_DIR"
}

# Build Android APK
build_android_apk() {
    print_status "Building Android APK..."
    
    cd android_controller
    
    # Kill any existing Flutter processes to prevent file watcher conflicts
    pkill -f "flutter" 2>/dev/null || true
    
    # Clean previous builds
    flutter clean
    flutter pub get
    
    # Build release APK (ARM64-v8a only)
    print_status "Building ARM64-v8a APK (this may take a few minutes)..."
    flutter build apk --release --target-platform android-arm64 --no-pub --no-tree-shake-icons
    
    # Copy APK file to build directory
    if [ -d "build/app/outputs/flutter-apk" ]; then
        cp build/app/outputs/flutter-apk/app-release.apk "../$BUILD_DIR/android/$APK_NAME"
    else
        print_error "APK build failed - output directory not found"
        exit 1
    fi
    
    cd ..
    
    print_success "Android APK built successfully"
}

# Create server distribution
create_server_distribution() {
    print_status "Creating server distribution..."
    
    # Common server files
    cp server/server.py "$BUILD_DIR/server-common/"
    cp server/config.json "$BUILD_DIR/server-common/"
    cp server/requirements.txt "$BUILD_DIR/server-common/"
    cp server/test_server.py "$BUILD_DIR/server-common/"
    
    # Create Windows distribution
    print_status "Creating Windows server distribution..."
    cp -r "$BUILD_DIR/server-common/"* "$BUILD_DIR/server-windows/"
    cp server/run-server.bat "$BUILD_DIR/server-windows/"
    
    # Create Linux distribution  
    print_status "Creating Linux server distribution..."
    cp -r "$BUILD_DIR/server-common/"* "$BUILD_DIR/server-linux/"
    cp server/run-server.sh "$BUILD_DIR/server-linux/"
    chmod +x "$BUILD_DIR/server-linux/run-server.sh"
    
    print_success "Server distribution created"
}


# Create README files for distributions
create_distribution_readmes() {
    print_status "Creating distribution README files..."
    
    # Android README
    cat > "$BUILD_DIR/android/README.md" << EOF
# Flow Controller APK

## Installation

1. Enable "Unknown sources" or "Install unknown apps" in your Android settings
2. Install the APK: **flow-controller-${VERSION}.apk**
   - **ARM64-v8a architecture** - Compatible with all modern Android devices (2018+)
   - **Optimized size and performance** for 64-bit ARM processors

## Compatibility

- **Supported**: All modern Android devices (ARM64-v8a)
- **Android Version**: 5.0+ (API level 21)
- **Processor**: 64-bit ARM (most phones from 2018 onwards)

## First Run

1. Open the app
2. Configure your server connection:
   - Enter your PC's IP address
   - Enter the port (default: 8080)
   - Enter your API token (same as in server config.json)
3. Test the connection
4. Start controlling your PC!

## Usage

- **Swipe** in any direction for arrow keys
- **Hold** after swiping to repeat the arrow key
- **Tap** anywhere for Enter
- **Double-tap** anywhere for ESC
- Use **Volume** buttons at the bottom
- Tap **Keyboard** for instant keystroke sending

Built on: $(date)
Version: ${VERSION}
Architecture: ARM64-v8a
EOF

    # Windows Server README
    cat > "$BUILD_DIR/server-windows/README.md" << EOF
# Flow Controller Server - Windows

## Quick Start

1. Edit \`config.json\` and change the API token
2. Run \`run-server.bat\` - it handles everything automatically!

## Files

- **run-server.bat** - One-click server runner (auto venv setup)
- **server.py** - Main server application
- **config.json** - Server configuration (EDIT THIS!)
- **requirements.txt** - Python dependencies
- **test_server.py** - Test script to verify server functionality

## Requirements

- Windows 10/11
- Python 3.8+ (download from https://www.python.org/downloads/)

## How it works

The \`run-server.bat\` script automatically:
- Creates a Python virtual environment (if needed)
- Installs dependencies
- Checks your configuration
- Starts the server

## Troubleshooting

- If script fails, make sure Python is installed and added to PATH
- If server won't start, check that port 8080 is not in use
- Check Windows Firewall settings if Android app can't connect

Built on: $(date)
Version: ${VERSION}
EOF

    # Linux Server README
    cat > "$BUILD_DIR/server-linux/README.md" << EOF
# Flow Controller Server - Linux

## Quick Start

1. Edit \`config.json\` and change the API token
2. Run \`./run-server.sh\` - it handles everything automatically!

## Files

- **run-server.sh** - One-click server runner (auto venv setup)
- **server.py** - Main server application
- **config.json** - Server configuration (EDIT THIS!)
- **requirements.txt** - Python dependencies
- **test_server.py** - Test script to verify server functionality

## Requirements

- Linux distribution with Python 3.8+
- For Ubuntu/Debian: \`sudo apt install python3 python3-pip python3-venv\`
- For volume control: ALSA or PulseAudio

## How it works

The \`./run-server.sh\` script automatically:
- Creates a Python virtual environment (if needed)
- Installs dependencies
- Checks your configuration
- Starts the server

## Troubleshooting

- If script fails, install python3-venv: \`sudo apt install python3-venv\`
- If server won't start, check that port 8080 is not in use
- Check firewall settings if Android app can't connect
- For volume control issues, ensure ALSA/PulseAudio is running

Built on: $(date)
Version: ${VERSION}
EOF

    print_success "Distribution README files created"
}

# Create build summary
create_build_summary() {
    print_status "Creating build summary..."
    
    cat > "$BUILD_DIR/BUILD_INFO.md" << EOF
# Build Summary

**Build Date:** $(date)
**Build Version:** ${VERSION}
**Build Host:** ${BUILD_HOST}
**Build User:** ${BUILD_USER}
**Flutter Version:** $(flutter --version | head -n 1)
**Python Version:** $(python3 --version)
**Platform:** Linux (build server)

## Contents

### Android APK (\`android/\`)
- ARM64-v8a APK (optimized for modern Android devices)
- Smaller size and better performance than universal APK

### Windows Server (\`server-windows/\`)
- Complete server package with setup and run scripts
- Requires Windows 10/11 and Python 3.8+

### Linux Server (\`server-linux/\`)
- Complete server package with setup and run scripts
- Requires Linux with Python 3.8+

## Installation Instructions

1. **Android**: Install appropriate APK on your phone
2. **Server**: Choose Windows or Linux folder, run setup script, then run script
3. **Configure**: Edit server config.json with your API token
4. **Connect**: Use Android app to connect to server

## File Sizes

EOF
    
    # Add file sizes
    find "$BUILD_DIR" -type f -exec ls -lh {} \; | awk '{print "- " $9 ": " $5}' >> "$BUILD_DIR/BUILD_INFO.md"
    
    print_success "Build summary created"
}

# Create distributable packages
create_distributable_packages() {
    print_status "Creating distributable packages..."
    
    # Copy APK to distributable folder
    cp "$BUILD_DIR/android/$APK_NAME" "$DIST_DIR/"
    
    # Create Windows server zip
    print_status "Creating Windows server zip..."
    cd "$BUILD_DIR"
    zip -r "../$DIST_DIR/flow-controller-server-windows-${VERSION}.zip" server-windows/
    
    # Create Linux server zip
    print_status "Creating Linux server zip..."
    zip -r "../$DIST_DIR/flow-controller-server-linux-${VERSION}.zip" server-linux/
    
    cd ..
    
    # Create distributable README
    cat > "$DIST_DIR/README.md" << EOF
# Flow Controller - Distribution Package

**Version:** ${VERSION}  
**Built:** $(date)

## Contents

### 📱 Android App
- **${APK_NAME}** - Install this APK on your Android phone
- **Architecture:** ARM64-v8a (compatible with all modern Android devices)
- **Requirements:** Android 5.0+ (API level 21)

### 🖥️ Windows Server
- **flow-controller-server-windows-${VERSION}.zip** - Extract and run on Windows PC
- **Requirements:** Windows 10/11 + Python 3.8+
- **Quick Start:** Extract zip → Edit config.json → Run run-server.bat

### 🐧 Linux Server  
- **flow-controller-server-linux-${VERSION}.zip** - Extract and run on Linux PC
- **Requirements:** Linux + Python 3.8+
- **Quick Start:** Extract zip → Edit config.json → Run ./run-server.sh

## Installation Steps

### 1. Install Android App
1. Enable "Unknown sources" in Android settings
2. Install **${APK_NAME}** on your phone

### 2. Set up Server (Windows or Linux)
1. Extract the appropriate server zip file
2. Edit **config.json** and change the API token to something secure
3. Run the server:
   - **Windows:** Double-click **run-server.bat**
   - **Linux:** Run **./run-server.sh**

### 3. Connect
1. Open the Android app
2. Configure server connection (IP address, port 8080, your API token)
3. Test connection and start controlling your PC!

## Usage
- **Swipe** in any direction for arrow keys
- **Hold** after swiping to repeat the arrow key  
- **Tap** anywhere for Enter
- **Double-tap** anywhere for ESC
- Use **Volume** buttons at the bottom
- Tap **Keyboard** for instant keystroke sending

## Support
- Check the README.md files inside each server package for detailed setup instructions
- Test your server with the included test_server.py script

---
**Flow Controller** - Control your PC from your phone with simple gestures!
EOF
    
    print_success "Distributable packages created"
}

# Main build process
main() {
    print_status "Starting build process on Linux..."
    echo
    
    check_prerequisites
    setup_build_dir
    build_android_apk
    create_server_distribution
    create_distribution_readmes
    create_build_summary
    create_distributable_packages
    
    echo
    print_success "🎉 Build completed successfully!"
    echo
    echo "📦 Distributable packages created in: $DIST_DIR"
    echo
    echo "Contents:"
    echo "├── ${APK_NAME} (Android APK)"
    echo "├── flow-controller-server-windows-${VERSION}.zip"
    echo "├── flow-controller-server-linux-${VERSION}.zip"
    echo "└── README.md (installation instructions)"
    echo
    echo "🏗️  Working build directory: $BUILD_DIR"
    echo "├── android/ (APK + README)"
    echo "├── server-windows/ (Windows server files)"
    echo "├── server-linux/ (Linux server files)"
    echo "└── BUILD_INFO.md"
    echo
    echo "📁 Distributable directory: $DIST_DIR"
    echo "📱 Android APK: $DIST_DIR/$APK_NAME"
    echo "🖥️  Windows server: $DIST_DIR/flow-controller-server-windows-${VERSION}.zip"
    echo "🐧 Linux server: $DIST_DIR/flow-controller-server-linux-${VERSION}.zip"
    echo
    echo "Ready for distribution! 🚀"
    echo
    echo "💡 Share the contents of the '$DIST_DIR' folder - it has everything users need!"
}

# Run main function
main "$@"
