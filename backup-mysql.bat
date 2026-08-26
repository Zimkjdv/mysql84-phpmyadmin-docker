@echo off
setlocal

cd /d "%~dp0"

if not exist ".env" (
    echo ERROR: .env was not found.
    exit /b 1
)

if not exist "backup" mkdir "backup"

echo Creating MySQL backup...

for /f "delims=" %%T in ('powershell.exe -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd-HH-mm-ss'"') do set "TIMESTAMP=%%T"
if not defined TIMESTAMP (
    echo ERROR: Failed to generate a timestamp.
    exit /b 1
)

set "BACKUP_FILE=backup\all-databases-%TIMESTAMP%.sql"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$line = Get-Content -LiteralPath '.env' | Select-String '^MYSQL_ROOT_PASSWORD=' | Select-Object -First 1; if (-not $line) { Write-Error 'MYSQL_ROOT_PASSWORD was not found in .env'; exit 1 }; $password = $line.Line.Split('=',2)[1]; $output = $env:BACKUP_FILE; docker compose exec -T mysql mysqldump -uroot ('-p' + $password) --all-databases --single-transaction | Out-File -Encoding utf8 -FilePath $output; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }"

if errorlevel 1 (
    echo ERROR: MySQL backup failed.
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; $line = Get-Content -LiteralPath '.env' | Select-String '^BACKUP_PATHS=' | Select-Object -First 1; $paths = if ($line) { $line.Line.Split('=',2)[1].Trim() } else { '' }; if ($paths) { foreach ($item in ($paths -split ';')) { $destination = $item.Trim(); if (-not $destination) { continue }; if (-not [IO.Path]::IsPathRooted($destination)) { $destination = Join-Path (Get-Location) $destination }; New-Item -ItemType Directory -Force -Path $destination | Out-Null; $target = Join-Path $destination (Split-Path -Leaf $env:BACKUP_FILE); Copy-Item -LiteralPath $env:BACKUP_FILE -Destination $target -Force; Write-Output ('Additional backup: ' + $target) } }"
if errorlevel 1 (
    echo ERROR: Failed to copy the backup to an additional path.
    exit /b 1
)

echo Backup completed:
echo %~dp0%BACKUP_FILE%
pause
