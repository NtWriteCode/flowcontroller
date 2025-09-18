#!/usr/bin/env python3
"""
Android PC Controller Server
Cross-platform server for receiving remote control commands from Android app
"""

import json
import os
import sys
import time
import threading
import subprocess
import re
from flask import Flask, request, jsonify
from pynput import keyboard
from pynput.keyboard import Key, Listener
import platform
import qrcode

# Platform-specific imports
if platform.system() == "Windows":
    try:
        from pycaw.pycaw import AudioUtilities, IAudioEndpointVolume
        from ctypes import cast, POINTER
        from comtypes import CLSCTX_ALL, CoInitialize, CoUninitialize
        WINDOWS_AUDIO = True
    except ImportError:
        WINDOWS_AUDIO = False
        print("Warning: Windows audio control not available")
elif platform.system() == "Linux":
    import subprocess
    LINUX_AUDIO = True
else:
    print(f"Warning: Unsupported platform {platform.system()}")
    WINDOWS_AUDIO = False
    LINUX_AUDIO = False

app = Flask(__name__)

# Global configuration
config = {}
keyboard_controller = keyboard.Controller()

def load_config():
    """Load configuration from config.json"""
    global config
    config_path = os.path.join(os.path.dirname(__file__), 'config.json')
    try:
        with open(config_path, 'r') as f:
            config = json.load(f)
    except FileNotFoundError:
        print(f"Config file not found at {config_path}")
        print("Please create config.json with your API token")
        sys.exit(1)
    except json.JSONDecodeError:
        print("Invalid JSON in config.json")
        sys.exit(1)

def authenticate_request():
    """Check if request has valid authentication"""
    auth_header = request.headers.get('Authorization')
    if not auth_header:
        return False
    
    if not auth_header.startswith('Bearer '):
        return False
    
    token = auth_header[7:]  # Remove 'Bearer ' prefix
    return token == config.get('api_token')

def require_auth(f):
    """Decorator to require authentication"""
    def decorated_function(*args, **kwargs):
        if not authenticate_request():
            # Drop the request silently as per requirements
            return '', 204
        return f(*args, **kwargs)
    decorated_function.__name__ = f.__name__
    return decorated_function

class VolumeController:
    """Cross-platform volume controller"""
    
    def __init__(self):
        self.platform = platform.system()
    
    def volume_up(self):
        """Increase system volume"""
        if self.platform == "Windows" and WINDOWS_AUDIO:
            self._windows_volume_up()
        elif self.platform == "Linux":
            self._linux_volume_up()
        else:
            # Fallback to keyboard shortcut
            keyboard_controller.press(Key.media_volume_up)
            keyboard_controller.release(Key.media_volume_up)
    
    def volume_down(self):
        """Decrease system volume"""
        if self.platform == "Windows" and WINDOWS_AUDIO:
            self._windows_volume_down()
        elif self.platform == "Linux":
            self._linux_volume_down()
        else:
            # Fallback to keyboard shortcut
            keyboard_controller.press(Key.media_volume_down)
            keyboard_controller.release(Key.media_volume_down)
    
    def _windows_volume_up(self):
        """Windows-specific volume up"""
        try:
            # Initialize COM
            CoInitialize()
            try:
                devices = AudioUtilities.GetSpeakers()
                interface = devices.Activate(IAudioEndpointVolume._iid_, CLSCTX_ALL, None)
                volume = cast(interface, POINTER(IAudioEndpointVolume))
                current_volume = volume.GetMasterVolumeLevelScalar()
                new_volume = min(1.0, current_volume + 0.1)
                volume.SetMasterVolumeLevelScalar(new_volume, None)
            finally:
                # Always uninitialize COM
                CoUninitialize()
        except Exception as e:
            print(f"Windows volume control error: {e}")
            # Fallback
            keyboard_controller.press(Key.media_volume_up)
            keyboard_controller.release(Key.media_volume_up)
    
    def _windows_volume_down(self):
        """Windows-specific volume down"""
        try:
            # Initialize COM
            CoInitialize()
            try:
                devices = AudioUtilities.GetSpeakers()
                interface = devices.Activate(IAudioEndpointVolume._iid_, CLSCTX_ALL, None)
                volume = cast(interface, POINTER(IAudioEndpointVolume))
                current_volume = volume.GetMasterVolumeLevelScalar()
                new_volume = max(0.0, current_volume - 0.1)
                volume.SetMasterVolumeLevelScalar(new_volume, None)
            finally:
                # Always uninitialize COM
                CoUninitialize()
        except Exception as e:
            print(f"Windows volume control error: {e}")
            # Fallback
            keyboard_controller.press(Key.media_volume_down)
            keyboard_controller.release(Key.media_volume_down)
    
    def _linux_volume_up(self):
        """Linux-specific volume up using amixer"""
        try:
            subprocess.run(['amixer', 'sset', 'Master', '5%+'], 
                         capture_output=True, check=True)
        except (subprocess.CalledProcessError, FileNotFoundError):
            # Fallback to pactl if amixer fails
            try:
                subprocess.run(['pactl', 'set-sink-volume', '@DEFAULT_SINK@', '+5%'], 
                             capture_output=True, check=True)
            except (subprocess.CalledProcessError, FileNotFoundError):
                # Final fallback
                keyboard_controller.press(Key.media_volume_up)
                keyboard_controller.release(Key.media_volume_up)
    
    def _linux_volume_down(self):
        """Linux-specific volume down using amixer"""
        try:
            subprocess.run(['amixer', 'sset', 'Master', '5%-'], 
                         capture_output=True, check=True)
        except (subprocess.CalledProcessError, FileNotFoundError):
            # Fallback to pactl if amixer fails
            try:
                subprocess.run(['pactl', 'set-sink-volume', '@DEFAULT_SINK@', '-5%'], 
                             capture_output=True, check=True)
            except (subprocess.CalledProcessError, FileNotFoundError):
                # Final fallback
                keyboard_controller.press(Key.media_volume_down)
                keyboard_controller.release(Key.media_volume_down)

# Initialize volume controller
volume_controller = VolumeController()

def get_system_mac_address():
    """Get the primary network interface MAC address"""
    try:
        if platform.system() == "Windows":
            # Windows: Try multiple methods for better compatibility
            try:
                # Method 1: getmac with table format (most compatible)
                result = subprocess.run(['getmac', '/fo', 'table', '/nh'], 
                                      capture_output=True, text=True, check=True)
                lines = result.stdout.strip().split('\n')
                for line in lines:
                    line = line.strip()
                    if line and not line.startswith('N/A'):
                        # Extract MAC address from table format
                        parts = line.split()
                        if parts:
                            mac_candidate = parts[0].strip()
                            if re.match(r'^([0-9A-Fa-f]{2}-){5}[0-9A-Fa-f]{2}$', mac_candidate):
                                if not mac_candidate.startswith('00-00-00-00-00-00'):
                                    return mac_candidate.replace('-', ':').upper()
            except subprocess.CalledProcessError:
                # Method 2: Simple getmac without format
                try:
                    result = subprocess.run(['getmac'], 
                                          capture_output=True, text=True, check=True)
                    lines = result.stdout.strip().split('\n')
                    for line in lines:
                        # Look for MAC address pattern in any format
                        mac_match = re.search(r'([0-9A-Fa-f]{2}[-:]){5}[0-9A-Fa-f]{2}', line)
                        if mac_match:
                            mac = mac_match.group().replace('-', ':').upper()
                            if not mac.startswith('00:00:00:00:00:00'):
                                return mac
                except subprocess.CalledProcessError:
                    # Method 3: Use ipconfig /all as fallback
                    try:
                        result = subprocess.run(['ipconfig', '/all'], 
                                              capture_output=True, text=True, check=True)
                        lines = result.stdout.split('\n')
                        for i, line in enumerate(lines):
                            # Look for "Physical Address" or "Physikalische Adresse" (German)
                            if ('Physical Address' in line or 'Physikalische Adresse' in line):
                                mac_match = re.search(r'([0-9A-Fa-f]{2}[-:]){5}[0-9A-Fa-f]{2}', line)
                                if mac_match:
                                    mac = mac_match.group().replace('-', ':').upper()
                                    if not mac.startswith('00:00:00:00:00:00'):
                                        return mac
                    except subprocess.CalledProcessError:
                        pass
        elif platform.system() == "Linux":
            # Linux: Read from /sys/class/net or use ip command
            try:
                # Try ip command first
                result = subprocess.run(['ip', 'link', 'show'], 
                                      capture_output=True, text=True, check=True)
                lines = result.stdout.split('\n')
                for line in lines:
                    if 'link/ether' in line and 'state UP' in lines[lines.index(line)-1]:
                        mac_match = re.search(r'link/ether\s+([0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2})', line)
                        if mac_match:
                            return mac_match.group(1).upper()
            except (subprocess.CalledProcessError, FileNotFoundError):
                # Fallback: check /sys/class/net
                net_dir = '/sys/class/net'
                if os.path.exists(net_dir):
                    for interface in os.listdir(net_dir):
                        if interface != 'lo':  # Skip loopback
                            mac_file = f'{net_dir}/{interface}/address'
                            if os.path.exists(mac_file):
                                with open(mac_file, 'r') as f:
                                    mac = f.read().strip().upper()
                                    if mac and mac != '00:00:00:00:00:00':
                                        return mac
        elif platform.system() == "Darwin":  # macOS
            result = subprocess.run(['ifconfig'], capture_output=True, text=True, check=True)
            lines = result.stdout.split('\n')
            for i, line in enumerate(lines):
                if 'en0:' in line or 'en1:' in line:  # Primary interfaces
                    # Look for ether line in the next few lines
                    for j in range(i+1, min(i+10, len(lines))):
                        if 'ether' in lines[j]:
                            mac_match = re.search(r'ether\s+([0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2})', lines[j])
                            if mac_match:
                                return mac_match.group(1).upper()
    except Exception as e:
        print(f"Error getting MAC address: {e}")
    
    # Final fallback: Use Python's uuid.getnode() and format it
    try:
        import uuid
        mac_int = uuid.getnode()
        if mac_int != uuid.getnode():  # Check if it's random (unreliable)
            return None
        # Convert to MAC address format
        mac_hex = f"{mac_int:012x}"
        mac_formatted = ':'.join(mac_hex[i:i+2] for i in range(0, 12, 2)).upper()
        if not mac_formatted.startswith('00:00:00:00:00:00'):
            print(f"Using Python uuid fallback method: {mac_formatted}")
            return mac_formatted
    except Exception as e:
        print(f"Python uuid fallback failed: {e}")
    
    return None

def generate_config_qr():
    """Generate QR code with server configuration for easy pairing"""
    try:
        # Get system MAC address
        mac_address = get_system_mac_address()
        
        # Create configuration data for QR code
        # If host is 0.0.0.0, try to get actual IP address for QR code
        host = config.get('host', '0.0.0.0')
        if host == '0.0.0.0':
            try:
                import socket
                # Get local IP address
                with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
                    s.connect(('8.8.8.8', 80))
                    host = s.getsockname()[0]
            except Exception:
                host = '0.0.0.0'  # Fallback
        
        qr_config = {
            "host": host,
            "port": config.get('port', 8080),
            "token": config.get('api_token', ''),
            "mac": mac_address or ''
        }
        
        # Generate QR code
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_M,
            box_size=1,
            border=1,
        )
        qr.add_data(json.dumps(qr_config))
        qr.make(fit=True)
        
        # Print ASCII QR code
        print("\n" + "="*50)
        print("📱 SCAN THIS QR CODE WITH YOUR PHONE")
        print("="*50)
        qr.print_ascii(invert=True)
        print("="*50)
        print("Or manually enter:")
        print(f"  IP: {qr_config['host']}")
        print(f"  Port: {qr_config['port']}")
        print(f"  Token: {qr_config['token']}")
        if mac_address:
            print(f"  MAC: {mac_address}")
        print("="*50 + "\n")
        
    except Exception as e:
        print(f"Could not generate QR code: {e}")
        print("Install qrcode library: pip install qrcode")

# API Endpoints

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint (no auth required)"""
    return jsonify({"status": "ok", "platform": platform.system()})

@app.route('/mac', methods=['GET'])
@require_auth
def get_mac_address():
    """Get the system's MAC address"""
    mac = get_system_mac_address()
    if mac:
        return jsonify({"status": "ok", "mac_address": mac})
    else:
        return jsonify({"status": "error", "message": "Could not determine MAC address"}), 404

@app.route('/arrow', methods=['POST'])
@require_auth
def arrow_key():
    """Send arrow key press"""
    data = request.get_json()
    if not data or 'direction' not in data:
        return jsonify({"error": "Missing direction"}), 400
    
    direction = data['direction'].lower()
    key_map = {
        'up': Key.up,
        'down': Key.down,
        'left': Key.left,
        'right': Key.right
    }
    
    if direction not in key_map:
        return jsonify({"error": "Invalid direction"}), 400
    
    key = key_map[direction]
    keyboard_controller.press(key)
    keyboard_controller.release(key)
    
    return jsonify({"status": "ok", "action": f"arrow_{direction}"})

@app.route('/key', methods=['POST'])
@require_auth
def key_press():
    """Send specific key press"""
    data = request.get_json()
    if not data or 'key' not in data:
        return jsonify({"error": "Missing key"}), 400
    
    key_name = data['key'].lower()
    
    if key_name == 'enter':
        keyboard_controller.press(Key.enter)
        keyboard_controller.release(Key.enter)
    elif key_name == 'backspace':
        keyboard_controller.press(Key.backspace)
        keyboard_controller.release(Key.backspace)
    elif key_name == 'escape':
        keyboard_controller.press(Key.esc)
        keyboard_controller.release(Key.esc)
    else:
        return jsonify({"error": "Unsupported key"}), 400
    
    return jsonify({"status": "ok", "action": f"key_{key_name}"})

@app.route('/type', methods=['POST'])
@require_auth
def type_text():
    """Type text string"""
    data = request.get_json()
    if not data or 'text' not in data:
        return jsonify({"error": "Missing text"}), 400
    
    text = data['text']
    keyboard_controller.type(text)
    
    return jsonify({"status": "ok", "action": "type", "length": len(text)})

@app.route('/volume', methods=['POST'])
@require_auth
def volume_control():
    """Control system volume"""
    data = request.get_json()
    if not data or 'action' not in data:
        return jsonify({"error": "Missing action"}), 400
    
    action = data['action'].lower()
    
    if action == 'up':
        volume_controller.volume_up()
    elif action == 'down':
        volume_controller.volume_down()
    else:
        return jsonify({"error": "Invalid volume action"}), 400
    
    return jsonify({"status": "ok", "action": f"volume_{action}"})

@app.errorhandler(404)
def not_found(error):
    """Return empty response for 404s to avoid leaking info"""
    return '', 204

@app.errorhandler(500)
def internal_error(error):
    """Return empty response for 500s to avoid leaking info"""
    return '', 204

def main():
    """Main entry point"""
    load_config()
    
    print(f"Starting Android PC Controller Server")
    print(f"Platform: {platform.system()}")
    print(f"Host: {config.get('host', '0.0.0.0')}")
    print(f"Port: {config.get('port', 8080)}")
    print(f"API Token: {config.get('api_token', 'NOT SET')}")
    print("\nEndpoints:")
    print("  GET  /health - Health check")
    print("  GET  /mac - Get MAC address")
    print("  POST /arrow - Arrow key press")
    print("  POST /key - Special key press (enter, backspace, escape)")
    print("  POST /type - Type text")
    print("  POST /volume - Volume control")
    
    # Generate and display QR code for easy pairing
    generate_config_qr()
    
    print("Press Ctrl+C to stop")
    
    try:
        # Use Waitress for production-ready server
        from waitress import serve
        serve(
            app,
            host=config.get('host', '0.0.0.0'),
            port=config.get('port', 8080),
            threads=4
        )
    except ImportError:
        print("Warning: Waitress not available, falling back to Flask development server")
        print("Install waitress for production use: pip install waitress")
        app.run(
            host=config.get('host', '0.0.0.0'),
            port=config.get('port', 8080),
            debug=False
        )
    except KeyboardInterrupt:
        print("\nServer stopped")

if __name__ == '__main__':
    main()
