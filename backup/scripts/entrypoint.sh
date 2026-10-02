#!/usr/bin/env bash
set -euo pipefail

INTERVAL="${BACKUP_INTERVAL_SECONDS:-300}"

echo "[bdr-worker] Starting automated backup scheduler (Interval: ${INTERVAL}s)..."

while true; do
  /scripts/backup.sh || echo "[bdr-worker] Backup cycle failed"
  sleep "$INTERVAL"
done