# Production Hardening Plan

**Version:** 1.0
**Date:** 2026-04-05
**Status:** Design Document (Pre-Implementation)
**Author:** Ahmet Abdullah Gultekin
**Project:** FIVUCSAS - Face and Identity Verification Using Cloud-Based SaaS
**Organization:** Marmara University - Computer Engineering Department

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Current Production State](#2-current-production-state)
3. [Penetration Testing](#3-penetration-testing)
4. [Performance Benchmarks and SLAs](#4-performance-benchmarks-and-slas)
5. [Disaster Recovery Plan](#5-disaster-recovery-plan)
6. [Monitoring and Alerting](#6-monitoring-and-alerting)
7. [Backup Verification](#7-backup-verification)
8. [Zero-Downtime Deployment](#8-zero-downtime-deployment)
9. [SSL and Certificate Management](#9-ssl-and-certificate-management)
10. [Database Maintenance](#10-database-maintenance)
11. [Log Aggregation](#11-log-aggregation)
12. [Incident Response Playbook](#12-incident-response-playbook)
13. [Implementation Phases](#13-implementation-phases)
14. [Risk Assessment](#14-risk-assessment)
15. [Dependencies and Prerequisites](#15-dependencies-and-prerequisites)

---

## 1. Executive Summary

FIVUCSAS is running in production on a Hetzner CX43 (8 CPU, 16 GB RAM, 150 GB disk) with 16 healthy containers serving real traffic. The platform has passed a security audit (9 critical + 34 high findings fixed, documented in AUDIT-2026-03-31.md), has 304 unit tests + 28 Playwright E2E tests + 103 API tests, and operates with automated daily backups. However, the system lacks formal SLAs, automated backup verification, zero-downtime deployment, centralized log aggregation, and a structured incident response process. This document defines the complete production hardening checklist to bring FIVUCSAS from "works in production" to "enterprise-ready production" with quantified uptime targets, tested disaster recovery, and operational runbooks.

---

## 2. Current Production State

### Infrastructure Overview

```
+------------------------------------------------------------------+
|  Hetzner CX43 — Nuremberg, Germany                               |
|  8 vCPU | 16 GB RAM | 150 GB NVMe | Ubuntu 24.04                |
+------------------------------------------------------------------+
|                                                                   |
|  Traefik v3.6.12 (reverse proxy, SSL termination)                |
|     |                                                             |
|     +-- api.fivucsas.com -> identity-core-api:8080    |
|     +-- bio.fivucsas.com -> biometric-api:8001|
|     +-- mizan.fivucsas.com -> mizan:3000               |
|     +-- sarnic.fivucsas.com -> sarnic:3001             |
|     +-- muhabbet.fivucsas.com -> muhabbet:5000         |
|                                                                   |
|  shared-postgres (PostgreSQL 17 + pgvector)                       |
|  shared-redis (Redis 7.4)                                         |
|  identity-core-api (Spring Boot 3.4.7, Java 21)                  |
|  biometric-api (FastAPI, Python 3.12, 4 GB RAM)                  |
|  + Mizan, Sarnic, Muhabbet, Share-Agent, VPN containers          |
|                                                                   |
|  Disk: ~36% used | RAM: ~36% used | Backups: daily at 03:00      |
+------------------------------------------------------------------+
```

### What Is Already Done

| Area | Status | Details |
|------|--------|---------|
| SSH hardening | Done | Key-only, fail2ban, IP whitelist |
| Docker security | Done | no-new-privileges, read_only, non-root |
| Firewall | Done | UFW: 22/80/443 only |
| SSL/TLS | Done | Let's Encrypt via Traefik, auto-renewal |
| Rate limiting | Done | Spring Boot + Traefik rate limits |
| Security audit | Done | Semgrep, Trivy, Hadolint, ShellCheck |
| Daily backups | Done | 4 databases, compressed, 7-day retention |
| VPN | Done | WireGuard (wg-easy) for admin access |
| Monitoring | Partial | Prometheus + Grafana deployed |
| CI/CD | Done | GitHub Actions, self-hosted runner |

### What Is Missing

| Area | Status | Priority |
|------|--------|----------|
| Penetration test | Not done | P0 |
| Formal SLAs | Not defined | P0 |
| Backup restore testing | Not automated | P0 |
| Zero-downtime deploy | Not implemented | P1 |
| Centralized logging | Not implemented | P1 |
| Alerting rules | Not configured | P1 |
| Incident response playbook | Not written | P1 |
| Database maintenance schedule | Ad-hoc | P2 |
| Chaos testing | Not done | P2 |

---

## 3. Penetration Testing

### Scope Definition

```
+------------------------------------------------------------------+
|                    PENTEST SCOPE                                  |
+------------------------------------------------------------------+
|                                                                   |
|  IN SCOPE:                                                        |
|  +------------------+  +------------------+  +------------------+ |
|  | Web Dashboard    |  | Identity Core    |  | Biometric        | |
|  | (React SPA)      |  | API (132 endpts) |  | Processor (46+)  | |
|  +------------------+  +------------------+  +------------------+ |
|  +------------------+  +------------------+  +------------------+ |
|  | Auth Widget      |  | OAuth 2.0 Flow   |  | WebAuthn Flow    | |
|  +------------------+  +------------------+  +------------------+ |
|  +------------------+  +------------------+                       |
|  | Android APK      |  | Network (SSH,    |                       |
|  | (decompile test) |  |  Traefik, ports) |                       |
|  +------------------+  +------------------+                       |
|                                                                   |
|  OUT OF SCOPE:                                                    |
|  - Hetzner hypervisor/host OS                                     |
|  - Hostinger shared hosting infrastructure                        |
|  - Third-party services (Stripe, GitHub)                          |
|  - Physical security                                              |
+------------------------------------------------------------------+
```

### Test Categories

| Category | Tests | Tools | Focus |
|----------|-------|-------|-------|
| Authentication | 15 | Burp Suite, custom scripts | JWT manipulation, session hijack, brute force |
| Authorization | 12 | Burp Suite | RBAC bypass, tenant isolation, IDOR |
| Injection | 10 | sqlmap, custom payloads | SQL injection, XSS, command injection |
| Biometric-specific | 8 | Custom scripts | Replay attacks, embedding poisoning, spoofing |
| API security | 10 | OWASP ZAP, Postman | Mass assignment, rate limit bypass, CORS |
| Infrastructure | 8 | nmap, nikto, testssl.sh | Port scan, TLS config, header analysis |
| Mobile | 5 | jadx, frida | APK decompile, certificate pinning, storage |
| Business logic | 7 | Manual | Enrollment bypass, verification flow skip |

### Biometric-Specific Tests

| Test | Attack Vector | Expected Defense |
|------|--------------|-----------------|
| Face replay (photo) | Show photo to camera | Passive liveness detection |
| Face replay (video) | Play video on screen | Active liveness (head turn, blink) |
| Voice replay | Play recorded audio | STT passphrase verification (W17) |
| Embedding injection | Submit crafted embedding via API | Server-side embedding extraction only |
| Template poisoning | Enroll with adversarial image | Quality gate rejects low-quality |
| Cross-tenant search | Query another tenant's gallery | RLS + tenant_id in every query |
| NFC chip cloning | Replayed APDU sequences | Challenge-response with random nonce |
| Rate limit bypass | Rotate IP/API key | Per-user + per-IP + global limits |

### Methodology: OWASP Testing Guide v4.2

```
Phase 1: Reconnaissance (1 day)
  - Port scan, service fingerprinting
  - Subdomain enumeration
  - Technology stack identification

Phase 2: Threat Modeling (0.5 day)
  - STRIDE analysis per component
  - Attack surface mapping
  - Data flow diagrams with trust boundaries

Phase 3: Vulnerability Assessment (3 days)
  - Automated scanning (ZAP, Burp, sqlmap)
  - Manual testing per category above
  - Biometric-specific tests

Phase 4: Exploitation (1 day)
  - Attempt to exploit discovered vulnerabilities
  - Chain vulnerabilities for impact amplification
  - Document proof-of-concept for each finding

Phase 5: Reporting (0.5 day)
  - CVSS v3.1 scoring
  - Remediation recommendations
  - Executive summary for stakeholders
```

---

## 4. Performance Benchmarks and SLAs

### Target SLAs

| Metric | Free Tier | Developer | Enterprise |
|--------|----------|-----------|------------|
| Uptime | 99.0% | 99.5% | 99.9% |
| API latency (P50) | <500ms | <300ms | <200ms |
| API latency (P95) | <2000ms | <1000ms | <500ms |
| Face verify latency | <2000ms | <1500ms | <1000ms |
| Voice verify latency | <1500ms | <1000ms | <800ms |
| Error rate | <5% | <1% | <0.1% |
| Data durability | 99.9% | 99.99% | 99.999% |

### Uptime Budget

| SLA | Annual Downtime | Monthly Downtime | Weekly Downtime |
|-----|----------------|-----------------|-----------------|
| 99.0% | 3.65 days | 7.3 hours | 1.68 hours |
| 99.5% | 1.83 days | 3.65 hours | 50 minutes |
| 99.9% | 8.76 hours | 43.8 minutes | 10 minutes |

### Load Testing Plan

```
Tool: k6 (already in load-tests/)

Scenario 1: Baseline (sustained)
  - 50 concurrent users
  - 60 minutes duration
  - Mix: 40% face verify, 30% auth flow, 20% search, 10% enroll
  - Target: P95 < 1000ms, error rate < 1%

Scenario 2: Spike (burst)
  - Ramp from 10 to 200 users in 30 seconds
  - Hold for 5 minutes
  - Ramp down to 10 in 30 seconds
  - Target: No 5xx errors, P95 < 3000ms during spike

Scenario 3: Endurance (soak)
  - 30 concurrent users
  - 24 hours
  - Target: No memory leak, no connection pool exhaustion, stable latencies

Scenario 4: Stress (breaking point)
  - Ramp from 10 to 500 users over 30 minutes
  - Find the breaking point (when error rate > 5%)
  - Document max concurrent capacity
```

### Current Baseline (Estimated)

| Metric | Current | Target | Gap |
|--------|---------|--------|-----|
| Max concurrent users | ~30 (untested) | 100 | Needs load test |
| Face verify P95 | ~1500ms | <1000ms | Client-side ML (Phase 4.2) |
| Voice verify P95 | ~800ms | <600ms | Thread pool tuning |
| Auth flow P95 | ~2000ms | <1000ms | Connection pooling |
| Memory stability (24h) | Unknown | <5% drift | Needs soak test |

---

## 5. Disaster Recovery Plan

### Recovery Objectives

| Scenario | RTO (Recovery Time) | RPO (Data Loss) | Strategy |
|----------|-------------------|-----------------|----------|
| Container crash | <2 minutes | 0 | Docker restart policy: always |
| Database corruption | <30 minutes | <24 hours | Restore from daily backup |
| Server failure (hardware) | <2 hours | <24 hours | New CX43 + restore |
| Data center outage | <4 hours | <24 hours | Hetzner Falkenstein DC |
| Ransomware/compromise | <4 hours | <24 hours | Clean server + offsite backup |

### Backup Architecture

```
+------------------+     +------------------+     +-------------------+
| Daily Backup     | --> | Local Storage    | --> | Offsite Storage   |
| (03:00 cron)     |     | (/opt/backups/)  |     | (Hetzner Storage  |
|                  |     | 7-day retention  |     |  Box or S3)       |
| Databases:       |     |                  |     | 30-day retention  |
| - identity_core  |     | ~50 MB/day       |     |                   |
| - biometric_db   |     | compressed       |     | Encrypted with    |
| - muhabbet       |     |                  |     | GPG (AES-256)     |
| - sarnic         |     |                  |     |                   |
+------------------+     +------------------+     +-------------------+
```

### Disaster Recovery Runbook

```
SCENARIO: Complete Server Loss

1. Provision new CX43 (Hetzner Cloud Console)
   - Ubuntu 24.04, Nuremberg region
   - Estimated time: 5 minutes

2. Run server bootstrap script
   $ curl -sL https://raw.githubusercontent.com/.../bootstrap.sh | bash
   - Installs Docker, sets up deploy user, firewall, SSH keys
   - Estimated time: 10 minutes

3. Clone repositories
   $ cd /opt/projects && git clone --recurse-submodules ...
   - Estimated time: 5 minutes

4. Restore .env.prod files (from secure backup)
   - Decrypt GPG-encrypted env files
   - Place in each project directory
   - Estimated time: 5 minutes

5. Download latest backup from offsite
   $ ./scripts/restore-backup.sh --date latest
   - Downloads and decompresses database dumps
   - Estimated time: 10 minutes

6. Start infrastructure
   $ docker compose -f docker-compose.prod.yml --env-file .env.prod up -d
   - PostgreSQL + Redis start first
   - Estimated time: 5 minutes

7. Restore databases
   $ pg_restore -d identity_core /opt/backups/latest/identity_core.sql.gz
   $ pg_restore -d biometric_db /opt/backups/latest/biometric_db.sql.gz
   - Estimated time: 5 minutes

8. Start application containers
   $ ./infra/deploy.sh restart all
   - Estimated time: 10 minutes

9. Update DNS (if IP changed)
   - Cloudflare: api.fivucsas.com -> new IP
   - Estimated time: 2 minutes (instant propagation via Cloudflare)

10. Verify all services
    $ ./infra/deploy.sh status
    $ curl https://api.fivucsas.com/ping
    - Estimated time: 5 minutes

TOTAL ESTIMATED RECOVERY TIME: ~62 minutes
```

---

## 6. Monitoring and Alerting

### Monitoring Stack

```
+------------------------------------------------------------------+
|                    MONITORING ARCHITECTURE                         |
+------------------------------------------------------------------+
|                                                                   |
|  +------------------+     +------------------+                    |
|  | Prometheus       | --> | Grafana          |                    |
|  | (metrics scrape) |     | (dashboards)     |                    |
|  +------------------+     +--------+---------+                    |
|           |                        |                              |
|  Scrape targets:          Dashboards:                             |
|  - /actuator/prometheus   - System (CPU, RAM, disk, network)      |
|  - /metrics (biometric)   - Application (request rate, latency)   |
|  - node_exporter          - Database (connections, queries, size)  |
|  - cadvisor (containers)  - Biometric (verify success rate, EER)  |
|                           - Business (enrollments, verifications) |
|                                                                   |
|  +------------------+     +------------------+                    |
|  | Alertmanager     | --> | Notification     |                    |
|  | (rules engine)   |     | Channels         |                    |
|  +------------------+     +------------------+                    |
|                           | - Telegram bot   |                    |
|                           | - Email          |                    |
|                           | - PagerDuty      |                    |
|                           +------------------+                    |
+------------------------------------------------------------------+
```

### Alert Rules

| Alert | Condition | Severity | Action |
|-------|----------|----------|--------|
| ServiceDown | HTTP probe fails for >2 min | P0 / Critical | Telegram + email immediately |
| HighErrorRate | 5xx rate > 5% for 5 min | P0 / Critical | Telegram + email |
| HighLatency | P95 > 3s for 10 min | P1 / Warning | Telegram |
| DiskFull | Disk usage > 80% | P1 / Warning | Email |
| MemoryHigh | Container RAM > 90% for 5 min | P1 / Warning | Telegram |
| BackupFailed | Backup cron exit code != 0 | P1 / Warning | Email |
| CertExpiring | SSL cert expires in <14 days | P2 / Info | Email |
| DatabaseSlow | Query P95 > 1s for 10 min | P2 / Info | Email |
| VerifyFailRate | Face verify reject > 30% for 1h | P2 / Info | Email (may indicate model issue) |
| QuotaApproaching | Disk/RAM > 70% | P3 / Info | Weekly summary |

### Prometheus Rules (prometheus/rules.yml)

```yaml
groups:
  - name: fivucsas_alerts
    rules:
      - alert: ServiceDown
        expr: probe_success{job="blackbox"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "{{ $labels.instance }} is down"
          description: "HTTP probe has been failing for more than 2 minutes"

      - alert: HighErrorRate
        expr: |
          sum(rate(http_server_requests_seconds_count{status=~"5.."}[5m]))
          / sum(rate(http_server_requests_seconds_count[5m])) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Error rate above 5%"

      - alert: HighMemory
        expr: container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.9
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "{{ $labels.name }} memory above 90%"
```

---

## 7. Backup Verification

### Automated Restore Testing

```
Schedule: Weekly (Sunday 06:00, after Saturday backup)

+------------------+     +------------------+     +------------------+
| Download Latest  | --> | Spin Up Temp     | --> | Restore Into     |
| Backup Files     |     | PostgreSQL       |     | Temp Instance    |
|                  |     | (Docker, port    |     |                  |
|                  |     |  15432)          |     |                  |
+------------------+     +------------------+     +------------------+
                                                          |
                                                          v
                                                  +------------------+
                                                  | Validate:        |
                                                  | - Row counts     |
                                                  | - Key tables     |
                                                  | - pgvector ops   |
                                                  | - Sample queries |
                                                  +------------------+
                                                          |
                                                          v
                                                  +------------------+
                                                  | Report + Cleanup |
                                                  | - Email result   |
                                                  | - Remove temp DB |
                                                  +------------------+
```

### Validation Queries

```sql
-- Table existence
SELECT count(*) FROM information_schema.tables
WHERE table_schema = 'public';

-- Row counts for critical tables
SELECT 'users' as tbl, count(*) FROM users
UNION ALL SELECT 'tenants', count(*) FROM tenants
UNION ALL SELECT 'face_embeddings', count(*) FROM face_embeddings
UNION ALL SELECT 'voice_enrollments', count(*) FROM voice_enrollments
UNION ALL SELECT 'audit_logs', count(*) FROM audit_logs;

-- pgvector functionality
SELECT embedding <=> embedding AS self_distance
FROM face_embeddings LIMIT 1;
-- Expected: 0.0 (vector compared to itself)

-- Recent data (not stale)
SELECT max(created_at) FROM audit_logs;
-- Expected: within 24 hours
```

---

## 8. Zero-Downtime Deployment

### Current Deployment (Downtime: 30-60 seconds)

```
1. docker compose build (image rebuild)
2. docker compose up -d (container replacement)
   ^^ ~30-60s of downtime while container restarts
```

### Target: Rolling Update Strategy

```
+------------------+     +------------------+     +------------------+
| Build New Image  | --> | Health Check     | --> | Swap Traffic     |
| (no downtime)    |     | New Container    |     | (Traefik dynamic)|
+------------------+     | (on temp port)   |     +------------------+
                         +------------------+             |
                                                          v
                                                  +------------------+
                                                  | Stop Old         |
                                                  | Container        |
                                                  | (graceful drain) |
                                                  +------------------+
```

### Implementation with Docker Compose + Traefik

```yaml
# docker-compose.prod.yml (zero-downtime config)
services:
  identity-core-api:
    deploy:
      update_config:
        parallelism: 1
        delay: 10s
        order: start-first        # Start new before stopping old
      rollback_config:
        parallelism: 1
        delay: 10s
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/ping"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 30s
    labels:
      - "traefik.http.services.identity.loadbalancer.healthcheck.path=/ping"
      - "traefik.http.services.identity.loadbalancer.healthcheck.interval=5s"
```

### Deployment Script (deploy-zero-downtime.sh)

```bash
#!/bin/bash
SERVICE=$1

# 1. Build new image
docker compose -f docker-compose.prod.yml --env-file .env.prod build $SERVICE

# 2. Scale up (start new alongside old)
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --scale $SERVICE=2 --no-recreate

# 3. Wait for new container health check
echo "Waiting for new container to be healthy..."
sleep 30

# 4. Remove old container
OLD_CONTAINER=$(docker ps --filter "name=$SERVICE" --format '{{.ID}}' | tail -1)
docker stop --time 30 $OLD_CONTAINER

# 5. Scale back to 1
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --scale $SERVICE=1
```

---

## 9. SSL and Certificate Management

### Current Setup

- Traefik ACME (Let's Encrypt) with automatic renewal
- Certificates stored in `acme.json` (Traefik volume)
- Auto-renewal 30 days before expiry

### Hardening

| Task | Current | Target |
|------|---------|--------|
| TLS version | 1.2 + 1.3 | 1.3 only (for new clients) |
| Cipher suites | Traefik defaults | ECDHE+AESGCM only |
| HSTS | Enabled | max-age=63072000, includeSubDomains, preload |
| OCSP stapling | Not configured | Enable in Traefik |
| Certificate monitoring | None | Alert 14 days before expiry |
| CAA record | Not set | Add `0 issue "letsencrypt.org"` DNS record |

### Traefik TLS Configuration

```yaml
# traefik/dynamic/tls.yml
tls:
  options:
    default:
      minVersion: VersionTLS12
      cipherSuites:
        - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
        - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
        - TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
      sniStrict: true
    modern:
      minVersion: VersionTLS13
```

---

## 10. Database Maintenance

### Scheduled Maintenance Tasks

| Task | Frequency | Command | Purpose |
|------|-----------|---------|---------|
| VACUUM ANALYZE | Daily (04:00) | `vacuumdb --analyze --all` | Reclaim space, update statistics |
| REINDEX | Weekly (Sunday 05:00) | `reindex database identity_core` | Rebuild bloated indexes |
| pg_stat_reset | Monthly | `SELECT pg_stat_reset()` | Reset statistics counters |
| Table bloat check | Weekly | Custom query | Identify tables needing VACUUM FULL |
| Index usage check | Monthly | `pg_stat_user_indexes` | Drop unused indexes |
| Connection check | Hourly | `pg_stat_activity` | Identify long-running queries |
| pgvector HNSW rebuild | Monthly | `REINDEX INDEX idx_face_hnsw` | Maintain search quality |

### Maintenance Script

```bash
#!/bin/bash
# /opt/scripts/db-maintenance.sh
# Run via cron: 0 4 * * * /opt/scripts/db-maintenance.sh

DATABASES="identity_core biometric_db muhabbet sarnic"
PG_CONTAINER="shared-postgres"

for DB in $DATABASES; do
    echo "[$(date)] VACUUM ANALYZE on $DB"
    docker exec $PG_CONTAINER psql -U postgres -d $DB -c "VACUUM ANALYZE;"

    echo "[$(date)] Check table bloat on $DB"
    docker exec $PG_CONTAINER psql -U postgres -d $DB -c "
        SELECT schemaname, tablename,
               pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
               n_dead_tup,
               n_live_tup,
               CASE WHEN n_live_tup > 0
                    THEN round(n_dead_tup::numeric / n_live_tup * 100, 2)
                    ELSE 0
               END as dead_pct
        FROM pg_stat_user_tables
        WHERE n_dead_tup > 1000
        ORDER BY n_dead_tup DESC;
    "
done

# Weekly: REINDEX (only on Sundays)
if [ "$(date +%u)" = "7" ]; then
    for DB in $DATABASES; do
        echo "[$(date)] REINDEX on $DB"
        docker exec $PG_CONTAINER reindexdb -d $DB
    done
fi
```

### pgvector-Specific Maintenance

```sql
-- Check HNSW index health
SELECT indexname, pg_size_pretty(pg_relation_size(indexname::regclass)) as size
FROM pg_indexes
WHERE indexdef LIKE '%hnsw%';

-- Rebuild if search recall drops below 95%
REINDEX INDEX CONCURRENTLY idx_face_embeddings_hnsw;
REINDEX INDEX CONCURRENTLY idx_voice_enrollments_hnsw;
```

---

## 11. Log Aggregation

### Current State

- Each container logs to Docker (stdout/stderr)
- `docker logs <container>` for individual access
- No centralized search or retention policy

### Target Architecture

```
+------------------------------------------------------------------+
|  Containers (stdout/stderr)                                       |
|  identity-core-api | biometric-api | shared-postgres | traefik    |
+--------+--------------------+--------------------+---------------+
         |                    |                    |
         v                    v                    v
+------------------------------------------------------------------+
|  Promtail (log collector, Docker plugin)                         |
|  - Reads container logs via Docker socket                         |
|  - Adds labels: container_name, service, level                    |
|  - Parses JSON logs (Spring Boot), plain text (Python)            |
+------------------------------------------------------------------+
         |
         v
+------------------------------------------------------------------+
|  Loki (log storage)                                              |
|  - Stores compressed log chunks                                   |
|  - S3-compatible backend (Hetzner Storage Box)                    |
|  - 30-day retention                                               |
|  - Label-based indexing (not full-text)                            |
+------------------------------------------------------------------+
         |
         v
+------------------------------------------------------------------+
|  Grafana (visualization)                                         |
|  - Log Explorer: search by container, level, time range           |
|  - Dashboard: error rate trends, slow query logs                  |
|  - Alerts: trigger on log patterns (ERROR, CRITICAL)              |
+------------------------------------------------------------------+
```

### Resource Estimate

| Component | RAM | Disk | CPU |
|-----------|-----|------|-----|
| Promtail | 50 MB | Minimal | Minimal |
| Loki | 256 MB | ~1 GB/month (compressed) | Low |
| **Total** | ~300 MB | ~1 GB/month | Minimal |

### Log Format Standardization

```json
// identity-core-api (Spring Boot structured logging)
{
  "timestamp": "2026-04-05T12:00:00.000Z",
  "level": "INFO",
  "logger": "c.f.a.s.AuthenticateUserService",
  "message": "User authenticated successfully",
  "tenant_id": "abc-123",
  "user_id": "def-456",
  "method": "FACE",
  "duration_ms": 1250,
  "trace_id": "xyz-789"
}

// biometric-api (Python structured logging)
{
  "timestamp": "2026-04-05T12:00:00.000Z",
  "level": "INFO",
  "module": "face_verify",
  "message": "Face verification complete",
  "similarity": 0.92,
  "threshold": 0.75,
  "duration_ms": 890,
  "trace_id": "xyz-789"
}
```

---

## 12. Incident Response Playbook

### Severity Levels

| Level | Definition | Response Time | Example |
|-------|-----------|---------------|---------|
| P0 / Critical | Service completely down or data breach | 15 min | All APIs returning 5xx |
| P1 / Major | Significant degradation | 1 hour | Face verify latency >5s |
| P2 / Minor | Non-critical issue | 4 hours | Grafana dashboard down |
| P3 / Low | Cosmetic or improvement | Next business day | Log format inconsistency |

### Incident Response Flow

```
+------------------+
| Alert Triggered  |
| (Prometheus/     |
|  manual report)  |
+--------+---------+
         |
         v
+------------------+     +------------------+
| Acknowledge      | --> | Assess Severity  |
| (Telegram reply) |     | (P0/P1/P2/P3)   |
+------------------+     +--------+---------+
                                  |
                    +-------------+-------------+
                    |                           |
               P0/P1                        P2/P3
                    |                           |
                    v                           v
         +------------------+         +------------------+
         | Mitigate         |         | Schedule Fix     |
         | (restart, scale, |         | (next session)   |
         |  failover)       |         |                  |
         +--------+---------+         +------------------+
                  |
                  v
         +------------------+
         | Root Cause       |
         | Analysis         |
         | (within 24h)     |
         +--------+---------+
                  |
                  v
         +------------------+
         | Post-Mortem      |
         | (document,       |
         |  prevent         |
         |  recurrence)     |
         +------------------+
```

### Common Incident Runbooks

#### Runbook: Container OOMKilled

```
Symptom: Container exits with code 137
Diagnosis:
  $ docker inspect <container> | grep OOMKilled
  $ docker stats --no-stream
Fix:
  1. Check for memory leak: docker logs <container> | grep -i "memory\|heap"
  2. Increase memory limit in docker-compose.prod.yml
  3. Restart: docker compose up -d <service>
  4. If biometric-api: check model loading (DeepFace, Resemblyzer, Whisper)
Prevention:
  - Set memory alerts at 80% threshold
  - Monthly memory profiling
```

#### Runbook: Database Connection Exhaustion

```
Symptom: "too many connections" in logs
Diagnosis:
  $ docker exec shared-postgres psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"
  $ docker exec shared-postgres psql -U postgres -c "SELECT usename, state, count(*) FROM pg_stat_activity GROUP BY usename, state;"
Fix:
  1. Kill idle connections: SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state = 'idle' AND query_start < now() - interval '10 minutes';
  2. Restart affected application container
  3. Check HikariCP pool config (max_pool_size)
Prevention:
  - Set max_connections = 200 in postgresql.conf
  - HikariCP pool per service: max 20
  - Connection leak detection: leakDetectionThreshold = 30000
```

#### Runbook: SSL Certificate Failure

```
Symptom: Browser shows "NET::ERR_CERT_DATE_INVALID"
Diagnosis:
  $ docker exec traefik cat /acme.json | jq '.[] | .Certificates[].domain'
  $ echo | openssl s_client -connect api.fivucsas.com:443 2>/dev/null | openssl x509 -noout -dates
Fix:
  1. Force Traefik certificate renewal:
     $ docker exec traefik rm /acme.json
     $ docker restart traefik
  2. Wait 2 minutes for Let's Encrypt issuance
  3. Verify: curl -vI https://api.fivucsas.com
Prevention:
  - Alertmanager: cert expiry < 14 days
  - Traefik auto-renewal (should handle this)
```

---

## 13. Implementation Phases

### Phase 1 — Monitoring and Alerting (2 weeks)

| Task | Effort | Details |
|------|--------|---------|
| Prometheus alert rules | 2 days | 10 rules as defined above |
| Alertmanager + Telegram bot | 1 day | Notification channel setup |
| Grafana dashboards (4) | 3 days | System, Application, Database, Biometric |
| Loki + Promtail deployment | 2 days | Log aggregation with 30-day retention |
| Log format standardization | 2 days | JSON structured logging in both services |

### Phase 2 — Backup and Recovery (1 week)

| Task | Effort | Details |
|------|--------|---------|
| Offsite backup to Hetzner Storage Box | 1 day | GPG-encrypted, rsync |
| Automated restore test script | 2 days | Weekly cron, temp PostgreSQL, validation queries |
| Disaster recovery runbook | 1 day | Document full rebuild procedure |
| DR drill (test full restore) | 1 day | Execute runbook end-to-end |

### Phase 3 — Zero-Downtime Deploy (1 week)

| Task | Effort | Details |
|------|--------|---------|
| /ping endpoint on all services | 0.5 day | Already on identity-core-api; add to biometric-api |
| Docker Compose health checks | 1 day | Proper start_period, interval, retries |
| deploy-zero-downtime.sh script | 1.5 days | Scale up -> health check -> swap -> scale down |
| Traefik health check integration | 1 day | Dynamic routing based on container health |
| Rollback script | 1 day | Revert to previous image tag |

### Phase 4 — Database Maintenance (0.5 week)

| Task | Effort | Details |
|------|--------|---------|
| db-maintenance.sh script | 1 day | VACUUM, REINDEX, bloat check |
| Cron schedule | 0.5 day | Daily VACUUM, weekly REINDEX |
| pgvector HNSW monitoring | 0.5 day | Recall quality check query |
| Connection pool tuning | 0.5 day | HikariCP per-service optimization |

### Phase 5 — Penetration Test (1 week)

| Task | Effort | Details |
|------|--------|---------|
| Scope and threat model | 1 day | As defined in Section 3 |
| Automated scanning | 1 day | OWASP ZAP, sqlmap, testssl.sh |
| Manual testing | 2 days | Auth, RBAC, biometric-specific |
| Remediation | 1 day | Fix critical/high findings |
| Report | 0.5 day | CVSS scoring, executive summary |

### Phase 6 — Incident Response (0.5 week)

| Task | Effort | Details |
|------|--------|---------|
| Incident response playbook | 1 day | Severity levels, runbooks, escalation |
| On-call rotation setup | 0.5 day | Telegram alerting, acknowledgment flow |
| Post-mortem template | 0.5 day | Standardized format for RCA |
| Chaos test (kill random container) | 0.5 day | Verify auto-restart + alerts fire |

### Total Effort: ~6 weeks

```
Week 1-2:   Phase 1 (Monitoring, alerting, log aggregation)
Week 3:     Phase 2 (Backup verification, DR drill)
Week 4:     Phase 3 (Zero-downtime deployment)
Week 4.5:   Phase 4 (Database maintenance automation)
Week 5:     Phase 5 (Penetration testing)
Week 5.5:   Phase 6 (Incident response setup)
Week 6:     Buffer + chaos testing + documentation polish
```

---

## 14. Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Pentest reveals critical vulnerability | Medium | Critical | Fix before any public BaaS launch; allocate 1 week buffer |
| Loki consumes too much disk | Medium | Low | 30-day retention policy; compress + offsite |
| Zero-downtime deploy fails (race condition) | Low | Medium | Test thoroughly in staging; keep manual deploy as fallback |
| DR drill takes longer than 2 hours | Medium | Medium | Pre-build server snapshot; keep bootstrap script tested |
| Alert fatigue (too many false positives) | High | Medium | Tune thresholds iteratively; start with P0 alerts only |
| Database maintenance causes performance dip | Low | Low | Schedule during lowest-traffic window (03:00-05:00) |
| Monitoring stack itself goes down | Low | Medium | Prometheus/Grafana health checks; separate from app stack |

---

## 15. Dependencies and Prerequisites

### Technical Prerequisites

| Prerequisite | Status | Notes |
|-------------|--------|-------|
| Prometheus | Deployed | Needs alert rules configuration |
| Grafana | Deployed | Needs dashboards creation |
| Alertmanager | Not deployed | Install as Docker container |
| Loki | Not deployed | Install as Docker container |
| Promtail | Not deployed | Install as Docker sidecar |
| /ping endpoint | Partial | identity-core-api has it; biometric-api needs it |
| Hetzner Storage Box | Not provisioned | For offsite backup storage |
| Telegram bot | Not created | For alert notifications |

### Cost Estimate

| Item | Monthly Cost | Notes |
|------|-------------|-------|
| Hetzner Storage Box (100 GB) | ~3.50 EUR | Offsite backups |
| Telegram bot | Free | Unlimited messages |
| Loki/Promtail | Free (self-hosted) | ~300 MB RAM |
| Alertmanager | Free (self-hosted) | ~50 MB RAM |
| **Total** | **~3.50 EUR/month** | |

---

*Production hardening is not a one-time event but a continuous process. This document should be reviewed quarterly, and the incident response playbook should be tested with a chaos engineering drill at least twice per year. The penetration test should be repeated annually or after any major feature release (especially BYOD and BaaS).*
