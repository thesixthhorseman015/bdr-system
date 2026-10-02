# Automated Backup & Disaster Recovery (BDR) System

![BDR CI](https://github.com/<thesixthhorseman015>/<bdr-system>/actions/workflows/ci.yml/badge.svg)

PostgreSQL + MinIO + Docker Compose with automated backups, checksum
verification, off-site storage, and an automated disaster recovery drill.

## Quick start
```bash
cp .env.example .env
docker compose up -d