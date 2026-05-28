# Deployment Documentation

Deployment and operations guides for FIVUCSAS.

## Local Development

- **[START_ALL_SERVICES.md](START_ALL_SERVICES.md)** - How to start all services locally
- **BACKEND_DAY_1_PLAN.md** - Backend setup plan
- **BACKEND_NEXT_STEPS.md** - Backend next steps

## Quick Start All Services

See [START_ALL_SERVICES.md](START_ALL_SERVICES.md) for detailed instructions.

### Start Backend API
```bash
cd identity-core-api
./mvnw spring-boot:run
# Access: http://localhost:8080
```

### Start Biometric Service
```bash
cd biometric-processor
./venv/Scripts/activate
uvicorn app.main:app --reload --port 8001
# Access: http://localhost:8001
```

### Start Desktop App
```bash
cd mobile-app
./gradlew :desktopApp:run
```

## Production Deployment

Production is live on Hetzner CX43 via Docker Compose + Traefik (api.fivucsas.com). PostgreSQL with pgvector, Redis, and Loki/Grafana monitoring are all running.

## Environment Configuration

### Development
- H2 in-memory database
- Local file storage
- Debug logging enabled
- CORS permissive

### Production (Planned)
- PostgreSQL with pgvector extension
- Redis for caching and queuing
- Structured logging
- CORS restricted to specific origins
- HTTPS only
- Environment-based configuration

---

## Runbooks

Operator runbooks live in the `infra/` repo at `/opt/projects/infra/RUNBOOK_*.md`. They are the load-bearing on-call references — read these before touching production.

| Runbook | Path | When to use |
|---------|------|-------------|
| **Disk capacity** | [`infra/RUNBOOK_DISK.md`](https://github.com/Rollingcat-Software/FIVUCSAS/blob/master/infra/RUNBOOK_DISK.md) | Before any `docker compose build --no-cache` on the Hetzner CX43 host; on `ENOSPC` alerts. Documents the 5 defence-in-depth layers (per-container log caps, journald cap, hourly disk-guard, daily sweep, weekly aggressive prune). |
| **Audit log partitioning (pg_partman V57)** | [`infra/RUNBOOK_AUDIT_LOG_PARTMAN.md`](https://github.com/Rollingcat-Software/FIVUCSAS/blob/master/infra/RUNBOOK_AUDIT_LOG_PARTMAN.md) | When applying or reasoning about Flyway V57. pg_partman with monthly partitions, premake=12, retention 24 months; fail-soft when extension missing (`RAISE WARNING + RETURN`). Includes explicit opt-out `ALTER DATABASE identity_core SET app.skip_partman_v57='on'`. |
| **Disaster recovery** | `infra/RUNBOOK_DR.md` | Annual DR drill, or a real outage requiring restore from off-site backup. |
| **Flyway repair** | `infra/RUNBOOK_FLYWAY_REPAIR.md` | When `schema_history` is out of sync with the migrations on disk. |
| **Network** | `infra/RUNBOOK_NETWORK.md` | DNS, Traefik routing, firewall, VPN. |
| **Off-site retention** | `infra/RUNBOOK_OFFSITE_RETENTION.md` | Backup retention windows and rotation. |
| **PITR (point-in-time recovery)** | `infra/RUNBOOK_PITR.md` | Restore Postgres to a specific timestamp. |
| **Rollback** | `infra/RUNBOOK_ROLLBACK.md` | Rolling back a botched deploy (Docker image + migration). |
| **Secret rotation** | `infra/RUNBOOK_SECRET_ROTATION.md` | Quarterly secret rotation; emergency rotation after suspected leak. |

The two highlighted runbooks (`RUNBOOK_DISK.md` + `RUNBOOK_AUDIT_LOG_PARTMAN.md`) are the most frequently referenced from session memory. Check them first on any rebuild or migration question.

---

[← Back to Main Documentation](../README.md)
