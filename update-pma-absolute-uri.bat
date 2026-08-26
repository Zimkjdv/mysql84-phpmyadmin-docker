@echo off
setlocal

cd /d "%~dp0"

if not exist ".env" (
    echo ERROR: .env was not found.
    exit /b 1
)

for /f "delims=" %%I in ('powershell.exe -NoProfile -Command "$ip = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -ne $null } | ForEach-Object { $_.IPv4Address | Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } | Select-Object -First 1 -ExpandProperty IPAddress } | Select-Object -First 1; if ($ip) { Write-Output $ip }"') do set "LAN_IP=%%I"

set "PMA_URI=http://localhost/phpmyadmin/"
if defined LAN_IP (
    set "PMA_URI=http://%LAN_IP%/phpmyadmin/"
) else (
    echo WARNING: Could not detect an active LAN IPv4 address.
    echo Falling back to http://localhost/phpmyadmin/
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$path = Join-Path (Get-Location) '.env'; $lines = @(Get-Content -LiteralPath $path -Encoding UTF8); $value = 'PMA_ABSOLUTE_URI=' + $env:PMA_URI; if ($lines -match '^PMA_ABSOLUTE_URI=') { $lines = $lines | ForEach-Object { if ($_ -match '^PMA_ABSOLUTE_URI=') { $value } else { $_ } } } else { $lines += $value }; Set-Content -LiteralPath $path -Value $lines -Encoding utf8"
if errorlevel 1 (
    echo ERROR: Failed to update PMA_ABSOLUTE_URI in .env.
    exit /b 1
)

echo Detected LAN IP: %LAN_IP%
echo Updated PMA_ABSOLUTE_URI=%PMA_URI%
