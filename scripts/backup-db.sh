#!/bin/bash
# =============================================================================
# Скрипт резервного копирования базы данных PostgreSQL
# =============================================================================
# 
# Использование:
#   ./backup-db.sh [путь_назначения]
#
# Пример:
#   ./backup-db.sh /backup/mediawiki/db
# =============================================================================

set -e

# Конфигурация
DB_NAME="my_wiki"
DB_USER="wikiuser"
BACKUP_DIR="${1:-/backup/mediawiki/db}"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="mediawiki_db_${DATE}.sql.gz"
RETENTION_DAYS=7

# Логирование
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Начало резервного копирования PostgreSQL..."

# Создание директории бэкапа
mkdir -p "${BACKUP_DIR}"

# Создание бэкапа с помощью pg_dump
log "Создание бэкапа базы данных ${DB_NAME}..."
pg_dump -U "${DB_USER}" "${DB_NAME}" | gzip > "${BACKUP_DIR}/${BACKUP_FILE}"

# Проверка успешности
if [ -f "${BACKUP_DIR}/${BACKUP_FILE}" ]; then
    SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_FILE}" | cut -f1)
    log "Бэкап создан: ${BACKUP_FILE} (${SIZE})"
else
    log "ERROR: Не удалось создать бэкап!"
    exit 1
fi

# Удаление старых бэкапов
log "Удаление бэкапов старше ${RETENTION_DAYS} дней..."
find "${BACKUP_DIR}" -name "mediawiki_db_*.sql.gz" -mtime +${RETENTION_DAYS} -delete

log "Резервное копирование завершено."
