#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME:-booking_db}"
DB_USER="${POSTGRES_USER:-appuser}"
DB_NAME="${POSTGRES_DB:-bookings_db}"
BACKUP_DIR="./backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.dump"

mkdir -p "$BACKUP_DIR"

if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Error: Container '${CONTAINER_NAME}' is not running." >&2
    exit 1
fi

echo "Creating backup of '${DB_NAME}'..."
docker exec -t "$CONTAINER_NAME" pg_dump \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    -F c \
    --no-owner \
    --no-acl > "$BACKUP_FILE"

echo "Backup completed: ${BACKUP_FILE} ($(du -h "$BACKUP_FILE" | cut -f1))"
