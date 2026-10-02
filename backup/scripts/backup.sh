#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="/backups"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
BUCKET="${MINIO_BUCKET:-safe-vault}"
REMOTE="bdr/${BUCKET}/${PGDATABASE}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
FILE="${PGDATABASE}_${TIMESTAMP}.sql.gz"
TMP_FILE="${BACKUP_DIR}/${FILE}.partial"
FINAL_FILE="${BACKUP_DIR}/${FILE}"
VERIFY_DIR="$(mktemp -d)"

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"; }

# Mutual exclusion lock
exec 9>/tmp/bdr.lock
flock 9

on_exit() {
  local rc=$?
  rm -f "$TMP_FILE"
  rm -rf "$VERIFY_DIR"
  if [ "$rc" -ne 0 ]; then
    log "Backup failed with exit code $rc"
  fi
}
trap on_exit EXIT

log "Starting backup of database '${PGDATABASE}' on host '${PGHOST}'"

# 1. Stream dump directly through maximum gzip compression to partial file
pg_dump --no-owner --clean --if-exists | gzip -9 > "$TMP_FILE"

# 2. Verify gzip stream integrity
gzip -t "$TMP_FILE"

# 3. Verify dump completion marker
zcat "$TMP_FILE" | tail -n 5 | grep -q "PostgreSQL database dump complete"

# 4. Atomic rename to final file
mv "$TMP_FILE" "$FINAL_FILE"

# 5. Generate and verify local SHA-256 integrity checksum
cd "$BACKUP_DIR"
sha256sum "$FILE" > "${FILE}.sha256"
sha256sum -c "${FILE}.sha256"

SIZE="$(du -h "$FINAL_FILE" | cut -f1)"
log "Local backup OK: ${FILE} (${SIZE})"

# 6. Configure MinIO client and ensure target bucket exists
mc alias set bdr "$MINIO_ENDPOINT" "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" > /dev/null
mc mb --ignore-existing "bdr/${BUCKET}" > /dev/null

# 7. Upload backup snapshot and checksum to MinIO
mc cp --quiet "$FINAL_FILE" "${FINAL_FILE}.sha256" "${REMOTE}/"
log "Uploaded to ${REMOTE}/"

# 8. Download back and verify remote copy against original SHA-256
mc cp --quiet "${REMOTE}/${FILE}" "${VERIFY_DIR}/"
cp "${FINAL_FILE}.sha256" "${VERIFY_DIR}/"
( cd "$VERIFY_DIR" && sha256sum -c "${FILE}.sha256" )
log "Remote copy verified (checksum matches)"

# 9. Retention policy cleanup (Local and Remote)
find "$BACKUP_DIR" -type f \( -name '*.sql.gz' -o -name '*.sha256' \) -mtime +"$RETENTION_DAYS" -print -delete \
  | sed 's/^/[retention] local deleted: /' || true
mc rm --recursive --force --older-than "${RETENTION_DAYS}d" "${REMOTE}/" > /dev/null 2>&1 || true

log "Backup completed successfully"