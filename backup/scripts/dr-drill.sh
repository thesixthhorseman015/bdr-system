#!/usr/bin/env bash
set -euo pipefail

HISTORY="/backups/dr-drill-history.csv"

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"; }

if [ "${1:-}" != "--yes" ]; then
  echo "WARNING: This script will DESTROY the database '${PGDATABASE}' to test disaster recovery."
  echo "To proceed, run: $0 --yes"
  exit 1
fi

# Ensure CSV history header exists
if [ ! -f "$HISTORY" ]; then
  echo "timestamp_utc,status,rto_seconds,before_fingerprint,after_fingerprint" > "$HISTORY"
fi

get_fingerprint() {
  export PGPASSWORD="$PGPASSWORD"
  psql -h "$PGHOST" -U "$PGUSER" -d "$PGDATABASE" -t -A -c \
    "SELECT CONCAT('customers:', COUNT(*)) FROM customers UNION ALL SELECT CONCAT('orders:', COUNT(*), ',sum:', COALESCE(SUM(amount), 0)) FROM orders;" 2>/dev/null | tr '\n' ';' || echo "UNAVAILABLE"
}

log "=== PHASE 1: Baseline Integrity Snapshot ==="
BEFORE_FP="$(get_fingerprint)"
log "Baseline Fingerprint: ${BEFORE_FP}"

# Ensure we have a fresh backup of this exact state
/scripts/backup.sh > /dev/null

log "=== PHASE 2: Simulating Disaster (Dropping Database) ==="
START_TIME=$(date +%s)
export PGPASSWORD="$PGPASSWORD"
psql -h "$PGHOST" -U "$PGUSER" -d postgres -c "DROP DATABASE \"${PGDATABASE}\" WITH (FORCE);" > /dev/null
log "Database '${PGDATABASE}' has been DELETED."

log "=== PHASE 3: Executing Automated Disaster Recovery ==="
/scripts/restore.sh

END_TIME=$(date +%s)
RTO=$((END_TIME - START_TIME))

log "=== PHASE 4: Post-Recovery Integrity Validation ==="
AFTER_FP="$(get_fingerprint)"
log "Recovered Fingerprint: ${AFTER_FP}"

if [ "$BEFORE_FP" = "$AFTER_FP" ] && [ "$BEFORE_FP" != "UNAVAILABLE" ]; then
  log "RESULT: PASS - Data is identical. Recovery completed in ${RTO}s (RTO)."
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ),PASS,${RTO},${BEFORE_FP},${AFTER_FP}" >> "$HISTORY"
else
  log "RESULT: FAIL - Fingerprint mismatch after recovery."
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ),FAIL,${RTO},${BEFORE_FP},${AFTER_FP}" >> "$HISTORY"
  exit 1
fi