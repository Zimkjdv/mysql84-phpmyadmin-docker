@echo off
setlocal

cd /d "%~dp0"

echo [1/5] Checking Docker...
docker info >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker Desktop is not running or is not accessible.
    exit /b 1
)

echo [2/5] Checking .env...
if not exist ".env" (
    echo ERROR: .env was not found.
    echo Copy .env.example to .env and set the MySQL passwords first.
    exit /b 1
)

:choose_uri
echo [3/5] Choose the phpMyAdmin public URI...
choice /C YN /N /M "Use the detected LAN IP for phpMyAdmin? [Y/N]: "
if errorlevel 2 goto use_localhost
if errorlevel 1 goto use_lan_ip
goto choose_uri

:use_lan_ip
call "%~dp0update-pma-absolute-uri.bat"
if errorlevel 1 (
    echo ERROR: Failed to update PMA_ABSOLUTE_URI.
    exit /b 1
)
goto uri_updated

:use_localhost
set "PMA_URI=http://localhost/phpmyadmin/"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$path = Join-Path (Get-Location) '.env'; $lines = @(Get-Content -LiteralPath $path -Encoding UTF8); $value = 'PMA_ABSOLUTE_URI=' + $env:PMA_URI; $current = $lines | Where-Object { $_ -match '^PMA_ABSOLUTE_URI=' } | Select-Object -First 1; if ($current -ne $value) { if ($lines -match '^PMA_ABSOLUTE_URI=') { $lines = $lines | ForEach-Object { if ($_ -match '^PMA_ABSOLUTE_URI=') { $value } else { $_ } } } else { $lines += $value }; Set-Content -LiteralPath $path -Value $lines -Encoding utf8; Write-Output 'PMA_ABSOLUTE_URI updated to localhost.' } else { Write-Output 'PMA_ABSOLUTE_URI already uses localhost.' }"
if errorlevel 1 (
    echo ERROR: Failed to set PMA_ABSOLUTE_URI to localhost.
    exit /b 1
)
echo Using localhost: %PMA_URI%

:uri_updated

echo [4/5] Starting MySQL and phpMyAdmin...
docker compose -f compose.yaml up -d
if errorlevel 1 (
    echo ERROR: Failed to start the main Compose services.
    exit /b 1
)

echo [5/5] Starting Nginx path-based reverse proxy...
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
