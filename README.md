# Production PostgreSQL Backup & Disaster Recovery (BDR) System

![BDR CI](https://github.com/thesixthhorseman015/bdr-system/actions/workflows/ci.yml/badge.svg)

A containerized, resilient Backup & Disaster Recovery engine built for PostgreSQL using MinIO (S3-compatible storage), Docker Compose, and automated recovery rehearsals benchmarking Recovery Time Objective (RTO).

---

## Architecture

- **Primary Database (`app-postgres`):** PostgreSQL 16 hosting transactional data in `core_db`.
- **Cold Storage (`s3-storage`):** MinIO S3 object storage maintaining compressed snapshots and SHA-256 integrity digests in `safe-vault`.
- **Automation Engine (`recovery-worker`):** Lightweight Alpine worker running scheduled backups, checksum validation, and automated disaster drills.
- **Isolated Network (`app-network`):** Custom bridge network isolating database traffic.

---

## Core Operational Commands

### Check Service Health
```bash
docker compose ps