# Flow Controller

**Control your Windows/Linux PC remotely from your Android phone using intuitive gestures, keyboard input, and voice commands.**

## What is Flow Controller?

Flow Controller is a **two-component remote control system** that lets you control your computer from anywhere in your home network:

- **🖥️ Server Component** - Runs on your PC (Windows/Linux) that you want to control
- **📱 Android App** - Installed on your phone, acts as the remote control

**Why is this useful?**
- Control your PC from the couch while watching movies
- Navigate presentations without being tied to your computer
- Type on your PC using your phone's superior mobile keyboard
- Wake up sleeping computers automatically when you need them
- Perfect for media centers, presentations, or casual PC control

The server runs quietly in the background on your PC, waiting for commands from your phone. Your Android device becomes a powerful touchpad with gesture controls, system keyboard access, and smart features like automatic Wake-on-LAN.

![Platform](https://img.shields.io/badge/platform-Android-green)
![Server](https://img.shields.io/badge/server-Windows%20%7C%20Linux-blue)
![License](https://img.shields.io/badge/license-MIT-blue)

## ✨ Features

- **🎯 Gesture Control** - Swipe for arrow keys, tap for Enter, double-tap for ESC
- **⌨️ System Keyboard** - Use your favorite mobile keyboard for instant text input
- **🔊 Volume Control** - Dedicated buttons with real-time percentage display
- **🌙 Wake-on-LAN** - Automatically wake sleeping computers with any gesture
- **📡 Live Monitoring** - Real-time connection status with ping measurement
- **🚀 High Performance** - Instant response, 10+ gestures per second
- **🔐 Secure** - Token-based authentication with automatic MAC discovery

## 🚀 Quick Start

### 1. Download from Releases
Go to the [Releases](../../releases) page and download the latest version:
- `flow-controller-windows.zip` - For Windows PCs
- `flow-controller-linux.zip` - For Linux PCs  
- `flow-controller-release.apk` - Android app

### 2. Setup Server (on your PC)
**Windows:**
```cmd
# Extract flow-controller-windows.zip
# Double-click run-server.bat
```

**Linux:**
```bash
# Extract flow-controller-linux.zip
chmod +x run-server.sh
./run-server.sh
```

The server will start and show you the API token to use.

### 3. Setup Android App (on your phone)
- Install `flow-controller-release.apk`
- Enter your PC's IP address and the API token from step 2
- Tap "Test Connection" (MAC address auto-discovered)
- Start controlling your PC!

## 🎮 How to Use

### Gestures
- **Swipe** → Arrow keys (↑↓←→)
- **Swipe + Hold** → Repeated arrow keys
- **Single Tap** → Enter
- **Double Tap** → Escape

### Controls
- **Volume Buttons** → System volume up/down
- **Keyboard Button** → System keyboard for typing
- **Settings** → Configure server connection

### Wake-on-LAN
When your PC is asleep, any gesture automatically sends a magic packet to wake it up. No configuration needed - MAC address is discovered automatically when you test the connection.

## 🛠️ Technical Details

**Android App (Client):**
- Flutter/Dart framework
- Real-time server health monitoring
- Automatic network discovery
- Haptic feedback for all gestures

**PC Server:**
- Python Flask API running on your computer
- Cross-platform key simulation (`pynput`)
- Windows volume control (`pycaw`)
- Linux volume control (`amixer`)
- Token-based security

**Network:**
- HTTP REST API
- Wake-on-LAN magic packets
- ARP table MAC discovery
- Configurable broadcast addressing

## 📋 Requirements

**PC (Server):**
- Python 3.7+
- Windows 10+ or Linux
- Network connectivity

**Android Phone (Client):**
- Android 5.0+ (API 21+)
- Same network as your PC
- Internet permission

## 🔧 Configuration

PC server configuration is stored in `server/config.json`:
```json
{
  "host": "0.0.0.0",
  "port": 8080,
  "api_token": "your-secret-token-here"
}
```

The Android app automatically saves your settings and discovers your PC's MAC address for Wake-on-LAN functionality.

## 🏗️ Building from Source

**Requirements:**
- Linux build environment
- Flutter SDK
- Python 3.7+

**Build:**
```bash
./build.sh
```

This creates a `distributable` folder with:
- `flow-controller-release.apk` - Android app
- `flow-controller-windows.zip` - Windows PC server package
- `flow-controller-linux.zip` - Linux PC server package

## 📱 Screenshots

*Professional gesture control interface with real-time connection status, volume controls, and system keyboard integration.*

---

**Made for seamless PC control from your Android device. Simple setup, powerful features, instant response.**