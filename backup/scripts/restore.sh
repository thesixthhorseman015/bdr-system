#!/usr/bin/env bash
set -euo pipefail

BUCKET="${MINIO_BUCKET:-safe-vault}"
REMOTE="bdr/${BUCKET}/${PGDATABASE}"
RESTORE_DIR="$(mktemp -d)"

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"; }

# Mutual exclusion: cannot run concurrently with backup.sh
exec 9>/tmp/bdr.lock
flock 9

on_exit() {
  rm -rf "$RESTORE_DIR"
}
trap on_exit EXIT

# 1. Connect to MinIO
mc alias set bdr "$MINIO_ENDPOINT" "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" > /dev/null

# 2. Find the latest backup file in MinIO
LATEST_FILE="$(mc ls "$REMOTE/" | grep '\.sql\.gz$' | sort -k1,2 | tail -n 1 | awk '{print $NF}')"

if [ -z "$LATEST_FILE" ]; then
  log "ERROR: No backup found in MinIO under ${REMOTE}/"
  exit 1
fi

log "Latest remote backup identified: ${LATEST_FILE}"

# 3. Download the snapshot and its checksum
mc cp --quiet "${REMOTE}/${LATEST_FILE}" "${RESTORE_DIR}/"
mc cp --quiet "${REMOTE}/${LATEST_FILE}.sha256" "${RESTORE_DIR}/"

# 4. Verify SHA-256 integrity BEFORE touching PostgreSQL
( cd "$RESTORE_DIR" && sha256sum -c "${LATEST_FILE}.sha256" )
log "Snapshot integrity verified (SHA-256 match)"

# 5. Ensure target database exists
export PGPASSWORD="$PGPASSWORD"
psql -h "$PGHOST" -U "$PGUSER" -d postgres -tc "SELECT 1 FROM pg_database WHERE datname = '${PGDATABASE}'" | grep -q 1 || \
  psql -h "$PGHOST" -U "$PGUSER" -d postgres -c "CREATE DATABASE \"${PGDATABASE}\";"

# 6. Stream decompress and restore with transaction safety
log "Replaying database dump into '${PGDATABASE}'..."
gunzip -c "${RESTORE_DIR}/${LATEST_FILE}" | psql -h "$PGHOST" -U "$PGUSER" -d "$PGDATABASE" \
  --single-transaction -v ON_ERROR_STOP=1 -q

log "Database restoration completed successfully."