#!/bin/bash

# Android PC Controller - Local Server Runner
# Simple script to set up and run the server locally

set -e

# Check for quiet flag
QUIET_MODE=0
if [[ "$1" == "--quiet" ]] || [[ "$1" == "-q" ]]; then
    QUIET_MODE=1
fi

if [[ $QUIET_MODE -eq 0 ]]; then
    echo "🖥️  Android PC Controller - Local Server"
    echo "========================================"
    echo
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "server.py" ]; then
    print_error "server.py not found. Please run this script from the server directory."
    exit 1
fi

# Check Python
if ! command -v python3 >/dev/null 2>&1; then
    print_error "Python3 not found. Please install Python 3.8+ first."
    exit 1
fi

print_success "Python3 found: $(python3 --version)"

# Check if virtual environment exists, create if not
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
    if [ $? -ne 0 ]; then
        print_error "Failed to create virtual environment"
        exit 1
    fi
    print_success "Virtual environment created"
fi

# Activate virtual environment
source venv/bin/activate

# Install/update dependencies
echo "Installing dependencies..."
pip install --upgrade pip >/dev/null 2>&1
pip install -r requirements.txt >/dev/null 2>&1

if [ $? -ne 0 ]; then
    print_error "Failed to install dependencies"
    exit 1
fi

print_success "Dependencies installed"

# Check if config exists and has been customized
if [ ! -f "config.json" ]; then
    print_error "config.json not found!"
    echo "Please create server/config.json with your API token."
    echo "Example:"
    echo '{'
    echo '  "api_token": "secret-token",'
    echo '  "port": 8080,'
    echo '  "host": "0.0.0.0"'
    echo '}'
    exit 1
fi

# Check if API token has been changed from default
if grep -q "change-this-secret-token\|secret-token" config.json 2>/dev/null; then
    print_warning "Default API token detected!"
    echo "Please edit server/config.json and set a secure API token."
    echo
    if [[ $QUIET_MODE -eq 0 ]]; then
        read -p "Continue with default token? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Please update your API token in server/config.json"
            exit 1
        fi
    fi
fi

# Get server config for display
API_TOKEN=$(python3 -c "import json; print(json.load(open('config.json'))['api_token'])" 2>/dev/null || echo "unknown")
PORT=$(python3 -c "import json; print(json.load(open('config.json'))['port'])" 2>/dev/null || echo "8080")
HOST=$(python3 -c "import json; print(json.load(open('config.json'))['host'])" 2>/dev/null || echo "0.0.0.0")

echo
print_success "Server configuration:"
echo "  Host: $HOST"
echo "  Port: $PORT"
echo "  API Token: ${API_TOKEN:0:8}... (hidden)"
echo

# Start server
echo "Starting server..."
echo "Press Ctrl+C to stop"
echo
python3 server.py
