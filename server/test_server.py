#!/usr/bin/env python3
"""
Test script for Android PC Controller Server
"""

import requests
import json
import time

def test_server(host="localhost", port=8080, token="your-secret-token-here"):
    """Test all server endpoints"""
    
    base_url = f"http://{host}:{port}"
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {token}"
    }
    
    print(f"Testing server at {base_url}")
    print(f"Using token: {token}")
    print("-" * 50)
    
    # Test health check (no auth required)
    try:
        response = requests.get(f"{base_url}/health", timeout=3)
        print(f"Health check: {response.status_code}")
        if response.status_code == 200:
            print(f"Response: {response.json()}")
        print()
    except Exception as e:
        print(f"Health check failed: {e}")
        return
    
    # Test arrow keys
    directions = ["up", "down", "left", "right"]
    for direction in directions:
        try:
            response = requests.post(
                f"{base_url}/arrow",
                headers=headers,
                json={"direction": direction},
                timeout=2
            )
            print(f"Arrow {direction}: {response.status_code}")
        except Exception as e:
            print(f"Arrow {direction} failed: {e}")
    
    print()
    
    # Test special keys
    keys = ["enter", "backspace"]
    for key in keys:
        try:
            response = requests.post(
                f"{base_url}/key",
                headers=headers,
                json={"key": key},
                timeout=2
            )
            print(f"Key {key}: {response.status_code}")
        except Exception as e:
            print(f"Key {key} failed: {e}")
    
    print()
    
    # Test text input
    try:
        response = requests.post(
            f"{base_url}/type",
            headers=headers,
            json={"text": "Hello from test script!"},
            timeout=5
        )
        print(f"Text input: {response.status_code}")
    except Exception as e:
        print(f"Text input failed: {e}")
    
    print()
    
    # Test volume control
    volume_actions = ["up", "down"]
    for action in volume_actions:
        try:
            response = requests.post(
                f"{base_url}/volume",
                headers=headers,
                json={"action": action},
                timeout=2
            )
            print(f"Volume {action}: {response.status_code}")
        except Exception as e:
            print(f"Volume {action} failed: {e}")
    
    print()
    print("Test completed!")
    print("\nNote: This script will actually send keystrokes to your system.")
    print("Make sure you have a text editor or notepad open to see the results.")

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1:
        token = sys.argv[1]
    else:
        token = input("Enter your API token (or press Enter for default): ").strip()
        if not token:
            token = "your-secret-token-here"
    
    print("WARNING: This will send actual keystrokes to your system!")
    print("Make sure you have a text editor open to see the results.")
    confirm = input("Continue? (y/N): ").strip().lower()
    
    if confirm == 'y':
        test_server(token=token)
    else:
        print("Test cancelled.")
