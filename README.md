# MySQL 8.4 + phpMyAdmin Docker Environment

[English](README.md) | [繁體中文](README-CN.md)

Run MySQL 8.4 and phpMyAdmin with Docker Compose. MySQL binds to `127.0.0.1` by default, while phpMyAdmin is published on host port `8080`. Database files are persisted in a Docker named volume.

Image versions are configured through `MYSQL_IMAGE` and `PHPMYADMIN_IMAGE` in `.env`. See [VERSIONS.md](VERSIONS.md) for version details and inspection commands.

## Quick Start

Requirements: Docker Desktop, or Docker Engine with Docker Compose.

1. Create your environment file:

   ```powershell
   Copy-Item .env.example .env
   ```

   On macOS or Linux, use `cp .env.example .env`.

2. Edit `.env` and replace at least `MYSQL_ROOT_PASSWORD` and `MYSQL_PASSWORD` with strong passwords.

3. Start the services:

   ```bash
   docker compose up -d
   ```

4. Open phpMyAdmin at <http://localhost:8080>.

Sign in with `MYSQL_USER` and `MYSQL_PASSWORD` from `.env`. To manage all databases, use `root` and `MYSQL_ROOT_PASSWORD`. The server name is `mysql` and is normally filled in automatically.

## Proxy Selection Guide

Start the main services first:

```powershell
docker compose -f compose.yaml up -d
```

Then choose one of the following proxy options. All three proxies use host port `80` and cannot run at the same time:

| Proxy | Compose file | URL | Best for |
| --- | --- | --- | --- |
| Apache root path | `compose.apache-proxy.yaml` | `http://host-ip/` | phpMyAdmin only; simplest setup |
| Apache path-based | `compose.apache-path-proxy.yaml` | `http://host-ip/phpmyadmin/` | Multiple sites routed by IP path |
| Nginx path-based | `compose.nginx-path-proxy.yaml` | `http://host-ip/phpmyadmin/` | Multiple Python web/API services |

For example, to enable Nginx:

```powershell
docker compose -f compose.nginx-path-proxy.yaml up -d
```

On Windows, you can also run [`deploy-nginx-path-proxy.bat`](deploy-nginx-path-proxy.bat) to start the main services and Nginx proxy automatically. During deployment, choose `Y` to run [`update-pma-absolute-uri.bat`](update-pma-absolute-uri.bat) and use the detected LAN IP, or choose `N` to use `http://localhost/phpmyadmin/`. If `.env` already uses the localhost URL, it is reused without rewriting. You can run the update script separately whenever you want to refresh the LAN IP URL.

Stop the currently active proxy before switching:

```powershell
docker compose -f compose.nginx-path-proxy.yaml down
```

## Optional Apache Reverse Proxy

To let users open phpMyAdmin at `http://host-ip/` without entering `:8080`, optionally start `compose.apache-proxy.yaml`. It runs a separate Apache container on the host's port `80` and forwards requests to the existing phpMyAdmin container.

Start the main services first so they create `mysql84_network`, then start the proxy:

```powershell
docker compose -f compose.yaml up -d
docker compose -f compose.apache-proxy.yaml up -d
```

With the proxy enabled, use <http://localhost/> or <http://host-ip/>. To stop it, stop the proxy first and then the main services:

```powershell
docker compose -f compose.apache-proxy.yaml down
docker compose -f compose.yaml down
```

Host port `80` must be available or the Apache proxy container cannot start. Direct mode remains available at <http://localhost:8080>.

If the same host will proxy additional web applications, use the path-based proxy instead:

```powershell
docker compose -f compose.yaml up -d
docker compose -f compose.apache-path-proxy.yaml up -d
```

With it enabled, use <http://localhost/phpmyadmin/> or <http://host-ip/phpmyadmin/>. Both `compose.apache-proxy.yaml` and `compose.apache-path-proxy.yaml` use host port `80`, so start only one of them.

If redirects use the wrong path after login, set the full public URL in `.env`, for example `PMA_ABSOLUTE_URI=http://192.168.1.100/phpmyadmin/`, and recreate the phpMyAdmin container.

If you expect to add more Python web or API services, you can use the Nginx path-based reverse proxy instead:

```powershell
docker compose -f compose.yaml up -d
docker compose -f compose.nginx-path-proxy.yaml up -d
```

The Nginx configuration is in `nginx/path-proxy.conf`. It currently provides `/phpmyadmin/` and includes commented route examples for `/api/` and `/web/`. It uses host port `80`, so run only one of the Apache or Nginx proxy Compose files at a time.

## Connection Details

| Client | Host | Port |
| --- | --- | --- |
| Application on the host | `127.0.0.1` | `MYSQL_PORT` (default: `3306`) |
| Container on the same Compose network | `mysql` (service name) | `3306` |
| External PHP container on `mysql84_network` | `mysql84` | `3306` |
| phpMyAdmin | <http://localhost:8080> (use the host IP from the LAN) | `PMA_PORT` (default: `8080`) |

Example: `mysql://myapp_user:your_password@127.0.0.1:3306/myapp`

### Allow MySQL connections from the LAN

By default, MySQL is published only on the local host:

```yaml
ports:
  - "127.0.0.1:3306:3306"
```

To allow other computers on the LAN to connect, change it to:

```yaml
ports:
  - "0.0.0.0:3306:3306"
```

Then recreate the MySQL container:

```powershell
docker compose up -d --force-recreate mysql
```

LAN clients can connect using the Docker host's LAN IP and port `3306`, for example `192.168.1.100:3306`. Allow inbound TCP `3306` in Windows Firewall and use a least-privilege MySQL account. Keep MySQL restricted to `127.0.0.1` unless LAN access is required; never expose it directly to the public internet.

## Common Commands

```bash
docker compose ps              # Show service status
docker compose logs -f         # Follow logs
docker compose down            # Remove containers and keep data
docker compose restart         # Restart services
docker compose pull            # Pull newer images
docker compose up -d           # Start or recreate services
```

## Database Initialization

Place `.sql`, `.sql.gz`, or executable `.sh` files in `initdb/`. MySQL runs them in filename order only when the data volume is initialized **for the first time**, for example `001-schema.sql` and `002-seed.sql`.

Existing volumes do not rerun initialization scripts. Changing the database name, user, or passwords in `.env` also does not update an already initialized database.

Compose uses two volume mounts:

```yaml
volumes:
  - mysql84_data:/var/lib/mysql
  - ./initdb:/docker-entrypoint-initdb.d:ro
```

### `mysql84_data:/var/lib/mysql`

- `mysql84_data` is a Docker-managed named volume.
- `/var/lib/mysql` is the MySQL data directory inside the container.
- Data remains after `docker compose down` or container recreation.
- `docker compose down -v` removes the volume and its data.

### `./initdb:/docker-entrypoint-initdb.d:ro`

- `./initdb` is the initialization directory on the host.
- `/docker-entrypoint-initdb.d` is where the official MySQL image reads initialization scripts.
- `:ro` mounts the directory as read-only, so the container cannot modify the host files.
- Scripts run once, only when `mysql84_data` is new and uninitialized.

Example:

```text
initdb/
├── 001-create-tables.sql
└── 002-insert-data.sql
```

If initialization scripts are not needed, remove `./initdb:/docker-entrypoint-initdb.d:ro` from `compose.yaml`. MySQL and persistent storage will continue to work normally.

## Backup and Restore

Read the root password from `.env` and create a backup with PowerShell:

```powershell
$password = (Get-Content .env | Select-String '^MYSQL_ROOT_PASSWORD=').Line.Split('=',2)[1]
New-Item -ItemType Directory -Force backup | Out-Null
docker compose exec -T mysql mysqldump -uroot -p"$password" --all-databases --single-transaction | Out-File -Encoding utf8 backup/all-databases.sql
```

Restore:

```powershell
$password = (Get-Content .env | Select-String '^MYSQL_ROOT_PASSWORD=').Line.Split('=',2)[1]
Get-Content -Raw backup/all-databases.sql | docker compose exec -T mysql mysql -uroot -p"$password"
```

On Windows, you can also run [`backup-mysql.bat`](backup-mysql.bat) to create the backup automatically. The backup uses a timestamped filename, such as `backup/all-databases-2026-08-20-10-26-28.sql`, so previous backups are not overwritten.

To also copy backups to other locations, set `BACKUP_PATHS` in `.env`, separating multiple paths with semicolons:

```env
BACKUP_PATHS=D:\mysql-backups;\\server\share\mysql
```

The project `backup` directory is always kept. If `BACKUP_PATHS` is empty or missing, only the project backup is created. Relative paths are resolved from the project root.

SQL dumps may contain sensitive data. Store them securely.

## Remove All Data

The following command permanently removes the MySQL volume and its data:

```bash
docker compose down -v
```

The next startup creates a new database and reruns the files in `initdb/`.

## Notes

- `.env` is excluded by `.gitignore`; never commit credentials.
- Before upgrading, back up the database, update `MYSQL_IMAGE` or `PHPMYADMIN_IMAGE` in `.env`, and update `VERSIONS.md`.
- If a port is already in use, change `MYSQL_PORT` or `PMA_PORT` in `.env`.
- `compose.apache-proxy.yaml` is optional and must be started after the main Compose file because it joins the existing `mysql84_network`.
- To allow remote connections, change the `127.0.0.1` bindings in `compose.yaml` and secure access with a firewall, TLS, and strict permissions. Do not expose MySQL or phpMyAdmin directly to the public internet.
