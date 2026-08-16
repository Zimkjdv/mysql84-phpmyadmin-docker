# MySQL 8.4 + phpMyAdmin Docker 環境

[English](README.md) | [繁體中文](README-CN.md)

使用 Docker Compose 啟動 MySQL 8.4 與 phpMyAdmin。服務預設只綁定本機 `127.0.0.1`，資料儲存在 Docker named volume，重建容器不會遺失。

採用的映像版本集中設定於 `.env` 的 `MYSQL_IMAGE` 與 `PHPMYADMIN_IMAGE`；版本記錄與查詢方式請參閱 [VERSIONS.md](VERSIONS.md)。

## 快速開始

需求：Docker Desktop，或 Docker Engine 與 Docker Compose。

1. 建立環境變數檔：

   ```powershell
   Copy-Item .env.example .env
   ```

   macOS / Linux 可使用 `cp .env.example .env`。

2. 編輯 `.env`，至少替換 `MYSQL_ROOT_PASSWORD` 與 `MYSQL_PASSWORD` 為高強度密碼。

3. 執行 `docker compose up -d` 啟動服務。

4. 開啟 phpMyAdmin：<http://localhost:8080>

一般帳號使用 `.env` 的 `MYSQL_USER` / `MYSQL_PASSWORD`；若需管理所有資料庫，可使用 `root` / `MYSQL_ROOT_PASSWORD`。伺服器名稱為 `mysql`。

## 連線資訊

| 使用情境 | Host | Port |
| --- | --- | --- |
| 主機上的程式 | `127.0.0.1` | `MYSQL_PORT`，預設 `3306` |
| 同一 Compose network 的容器 | `mysql` | `3306` |
| phpMyAdmin | <http://localhost:8080> | `PMA_PORT`，預設 `8080` |

連線字串範例：`mysql://myapp_user:你的密碼@127.0.0.1:3306/myapp`

## 常用指令

```bash
docker compose ps              # 查看狀態
docker compose logs -f         # 查看日誌
docker compose down            # 移除容器並保留資料
docker compose restart         # 重新啟動
docker compose pull            # 更新映像
docker compose up -d           # 啟動或重建容器
```

## 初始化 SQL

將 `.sql`、`.sql.gz` 或可執行的 `.sh` 放進 `initdb/`。MySQL 只會在資料 volume **第一次建立**時依檔名順序執行，例如 `001-schema.sql`、`002-seed.sql`。既有 volume 不會再次執行初始化腳本，修改 `.env` 也不會更新已初始化的資料庫帳號或密碼。

```yaml
volumes:
  - mysql84_data:/var/lib/mysql
  - ./initdb:/docker-entrypoint-initdb.d:ro
```

### `mysql84_data:/var/lib/mysql`

- `mysql84_data` 是 Docker 管理的 named volume。
- `/var/lib/mysql` 是容器內的 MySQL 資料目錄。
- `docker compose down` 或重建容器會保留資料。
- `docker compose down -v` 會刪除 volume 及資料。

### `./initdb:/docker-entrypoint-initdb.d:ro`

- `./initdb` 是主機上的初始化腳本目錄。
- `/docker-entrypoint-initdb.d` 是官方映像讀取初始化腳本的位置。
- `:ro` 表示唯讀，容器不能修改主機檔案。
- 腳本只在 `mysql84_data` 全新且尚未初始化時執行一次。

```text
initdb/
├── 001-create-tables.sql
└── 002-insert-data.sql
```

若不需要初始化腳本，可以移除該掛載，不影響 MySQL 與資料持久化。

## 備份與還原

備份（PowerShell）：

```powershell
$password = (Get-Content .env | Select-String '^MYSQL_ROOT_PASSWORD=').Line.Split('=',2)[1]
New-Item -ItemType Directory -Force backup | Out-Null
docker compose exec -T mysql mysqldump -uroot -p"$password" --all-databases --single-transaction | Out-File -Encoding utf8 backup/all-databases.sql
```

還原：

```powershell
$password = (Get-Content .env | Select-String '^MYSQL_ROOT_PASSWORD=').Line.Split('=',2)[1]
Get-Content -Raw backup/all-databases.sql | docker compose exec -T mysql mysql -uroot -p"$password"
```

SQL dump 可能包含敏感資料，請妥善保管。

## 清除全部資料

`docker compose down -v` 會永久刪除 MySQL volume。再次啟動會建立全新資料庫並重新執行 `initdb/`。

## 注意事項

- `.env` 已被 `.gitignore` 排除，請勿提交密碼。
- 升級前請備份資料，再修改 `.env` 的映像版本並更新 `VERSIONS.md`。
- Port 被占用時，可修改 `.env` 的 `MYSQL_PORT` 或 `PMA_PORT`。
- 不建議直接將 MySQL 或 phpMyAdmin 公開到網際網路。
