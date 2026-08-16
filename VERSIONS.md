# 服務版本記錄

最後更新：2026-08-17

| 服務 | Docker image 設定 | 用途 |
| --- | --- | --- |
| MySQL | `mysql:8.4` | MySQL 8.4 LTS 系列 |
| phpMyAdmin | `phpmyadmin:5.2-apache` | phpMyAdmin 5.2 系列，Apache 版映像 |

這些是目前 Compose 採用的 image tag。`8.4` 與 `5.2-apache` 是可移動標籤；重新 pull 後，patch 版本、Apache 版本或 image digest 可能更新。實際部署版本應以正在執行的容器為準。

## 查詢實際版本

服務啟動後執行：

```powershell
# MySQL 完整版本
docker compose exec mysql mysql --version

# phpMyAdmin 版本
docker compose exec phpmyadmin php -r "include '/var/www/html/libraries/classes/Version.php'; echo PhpMyAdmin\Version::VERSION, PHP_EOL;"

# Apache 版本
docker compose exec phpmyadmin apache2 -v

# 目前容器使用的 image 與不可變 digest
docker inspect mysql84 phpmyadmin --format '{{.Name}} | {{.Config.Image}} | {{.Image}}'
```

## 更新版本記錄

1. 備份 MySQL 資料。
2. 修改 `.env` 中的 `MYSQL_IMAGE` 或 `PHPMYADMIN_IMAGE`。
3. 執行 `docker compose pull` 與 `docker compose up -d`。
4. 執行上方查詢指令確認實際版本。
5. 更新本文件的日期、image tag；若需要完整可重現性，也一併記錄 image digest。
