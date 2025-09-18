@echo off
setlocal enabledelayedexpansion

REM Android PC Controller - Local Server Runner
REM Simple script to set up and run the server locally

REM Check for quiet flag
set QUIET_MODE=0
if "%~1"=="--quiet" set QUIET_MODE=1
if "%~1"=="-q" set QUIET_MODE=1

REM Hide console window if quiet mode (requires PowerShell)
if %QUIET_MODE%==1 (
    powershell -WindowStyle Hidden -Command "Start-Process cmd -ArgumentList '/c \"%~f0\" internal' -WindowStyle Hidden"
    if "%~2" NEQ "internal" exit /b 0
)

if %QUIET_MODE%==0 (
    echo 🖥️  Android PC Controller - Local Server
    echo ========================================
    echo.
)

REM Check if we're in the right directory
if not exist "server.py" (
    echo [ERROR] server.py not found. Please run this script from the server directory.
    if %QUIET_MODE%==0 pause
    exit /b 1
)

REM Check Python
python --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    python3 --version >nul 2>&1
    if %ERRORLEVEL% NEQ 0 (
        echo [ERROR] Python not found. Please install Python 3.8+ first.
        if %QUIET_MODE%==0 pause
        exit /b 1
    )
    set PYTHON_CMD=python3
) else (
    set PYTHON_CMD=python
)

echo [SUCCESS] Python found: 
%PYTHON_CMD% --version

REM Check if virtual environment exists, create if not
if not exist "venv" (
    echo Creating virtual environment...
    %PYTHON_CMD% -m venv venv
    if %ERRORLEVEL% NEQ 0 (
        echo [ERROR] Failed to create virtual environment
        if %QUIET_MODE%==0 pause
        exit /b 1
    )
    echo [SUCCESS] Virtual environment created
)

REM Activate virtual environment
call venv\Scripts\activate.bat

REM Install/update dependencies
echo Installing dependencies...
pip install --upgrade pip >nul 2>&1
pip install -r requirements.txt >nul 2>&1

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to install dependencies
    if %QUIET_MODE%==0 pause
    exit /b 1
)

echo [SUCCESS] Dependencies installed

REM Check if config exists
if not exist "config.json" (
    echo [ERROR] config.json not found!
    echo Please create config.json with your API token.
    echo Example:
    echo {
    echo   "api_token": "secret-token",
    echo   "port": 8080,
    echo   "host": "0.0.0.0"
    echo }
    if %QUIET_MODE%==0 pause
    exit /b 1
)

REM Check if API token has been changed from default
findstr "change-this-secret-token" config.json >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [WARNING] Default API token detected!
    echo Please edit config.json and set a secure API token.
    echo.
    if %QUIET_MODE%==0 (
        set /p "continue=Continue with default token? (y/N): "
        if /i not "!continue!"=="y" (
            echo Please update your API token in config.json
            pause
            exit /b 1
        )
    )
)

findstr "secret-token" config.json >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [WARNING] Default API token detected!
    echo Please edit config.json and set a secure API token.
    echo.
    if %QUIET_MODE%==0 (
        set /p "continue=Continue with default token? (y/N): "
        if /i not "!continue!"=="y" (
            echo Please update your API token in config.json
            pause
            exit /b 1
        )
    )
)

echo.
echo [SUCCESS] Starting server...
echo Press Ctrl+C to stop
echo.
%PYTHON_CMD% server.py

if %QUIET_MODE%==0 pause
