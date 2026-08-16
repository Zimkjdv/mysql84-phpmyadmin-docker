# MySQL 8.4 + phpMyAdmin Docker Environment

[English](README.md) | [繁體中文](README-CN.md)

Run MySQL 8.4 and phpMyAdmin with Docker Compose. Services bind to `127.0.0.1` by default, and database files are persisted in a Docker named volume.

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

## Connection Details

| Client | Host | Port |
| --- | --- | --- |
| Application on the host | `127.0.0.1` | `MYSQL_PORT` (default: `3306`) |
| Container on the same Compose network | `mysql` | `3306` |
| phpMyAdmin | <http://localhost:8080> | `PMA_PORT` (default: `8080`) |

Example: `mysql://myapp_user:your_password@127.0.0.1:3306/myapp`

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
- To allow remote connections, change the `127.0.0.1` bindings in `compose.yaml` and secure access with a firewall, TLS, and strict permissions. Do not expose MySQL or phpMyAdmin directly to the public internet.
