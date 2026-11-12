#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME:-booking_db}"
DB_USER="${POSTGRES_USER:-appuser}"
TARGET_DB="${1:-bookings_db_restored}"
BACKUP_FILE="${2:-}"

if [[ -z "$BACKUP_FILE" ]]; then
    BACKUP_FILE=$(ls -t ./backups/*.dump 2>/dev/null | head -n 1 || true)
fi

if [[ -z "$BACKUP_FILE" || ! -f "$BACKUP_FILE" ]]; then
    echo "Error: No backup file found. Pass path as second argument or run backup.sh first." >&2
    exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Error: Container '${CONTAINER_NAME}' is not running." >&2
    exit 1
fi

echo "Recreating fresh target database '${TARGET_DB}'..."
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d postgres -v ON_ERROR_STOP=1 <<-EOSQL
    SELECT pg_terminate_backend(pid) 
    FROM pg_stat_activity 
    WHERE datname = '${TARGET_DB}' AND pid <> pg_backend_pid();
    DROP DATABASE IF EXISTS ${TARGET_DB};
    CREATE DATABASE ${TARGET_DB};
EOSQL

echo "Restoring '${BACKUP_FILE}' into '${TARGET_DB}'..."
docker exec -i "$CONTAINER_NAME" pg_restore \
    -U "$DB_USER" \
    -d "$TARGET_DB" \
    --no-owner \
    --no-acl \
    --single-transaction < "$BACKUP_FILE"

echo "Restore complete. Verifying row counts in '${TARGET_DB}':"
docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$TARGET_DB" -c \
    "SELECT 'hotel_bookings' AS table_name, COUNT(*) FROM hotel_bookings
     UNION ALL
     SELECT 'booking_events' AS table_name, COUNT(*) FROM booking_events;"
