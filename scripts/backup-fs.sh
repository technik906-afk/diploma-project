#!/bin/bash
# =============================================================================
# Скрипт резервного копирования файловой системы MediaWiki
# =============================================================================
# 
# Использование:
#   ./backup-fs.sh [путь_назначения]
#
# Пример:
#   ./backup-fs.sh /backup/mediawiki/fs
# =============================================================================

set -e

# Конфигурация
MEDIAWIKI_DIR="/var/www/mediawiki"
BACKUP_DIR="${1:-/backup/mediawiki/fs}"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="mediawiki_fs_${DATE}.tar.gz"
RETENTION_DAYS=7

# Логирование
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Начало резервного копирования MediaWiki FS..."

# Создание директории бэкапа
mkdir -p "${BACKUP_DIR}"

# Создание архива
log "Создание архива ${BACKUP_FILE}..."
tar -czf "${BACKUP_DIR}/${BACKUP_FILE}" -C "$(dirname ${MEDIAWIKI_DIR})" "$(basename ${MEDIAWIKI_DIR})"

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
find "${BACKUP_DIR}" -name "mediawiki_fs_*.tar.gz" -mtime +${RETENTION_DAYS} -delete

log "Резервное копирование завершено."
