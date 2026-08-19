@echo off
setlocal

cd /d "%~dp0"

echo [1/4] Checking .env...
if not exist ".env" (
    echo ERROR: .env was not found.
    echo Copy .env.example to .env and set the MySQL passwords first.
    exit /b 1
)

echo [2/4] Checking Docker...
docker info >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker Desktop is not running or is not accessible.
    exit /b 1
)

echo [3/4] Starting MySQL and phpMyAdmin...
docker compose -f compose.yaml up -d
if errorlevel 1 (
    echo ERROR: Failed to start the main Compose services.
    exit /b 1
)

echo [4/4] Starting Nginx path-based reverse proxy...
docker compose -f compose.nginx-path-proxy.yaml up -d
if errorlevel 1 (
    echo ERROR: Failed to start the Nginx path proxy.
    exit /b 1
)

echo.
echo Deployment completed.
echo phpMyAdmin: http://localhost/phpmyadmin/
echo LAN access: http://YOUR-HOST-IP/phpmyadmin/
echo.
echo Main services:
docker compose -f compose.yaml ps
echo.
echo Nginx proxy:
docker compose -f compose.nginx-path-proxy.yaml ps

pause
