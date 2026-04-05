# Bring Your Own Database (BYOD) Architecture

**Version:** 1.0
**Date:** 2026-04-05
**Status:** Design Document (Pre-Implementation)
**Author:** Ahmet Abdullah Gultekin
**Project:** FIVUCSAS - Face and Identity Verification Using Cloud-Based SaaS
**Organization:** Marmara University - Computer Engineering Department
**Feature ID:** W18

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Business Context](#2-business-context)
3. [Architecture Overview](#3-architecture-overview)
4. [Tenant Configuration Model](#4-tenant-configuration-model)
5. [Dynamic DataSource Routing](#5-dynamic-datasource-routing)
6. [Connection Pool Management](#6-connection-pool-management)
7. [Security Architecture](#7-security-architecture)
8. [Migration Strategy](#8-migration-strategy)
9. [Implementation Phases](#9-implementation-phases)
10. [Risk Assessment](#10-risk-assessment)
11. [Dependencies and Prerequisites](#11-dependencies-and-prerequisites)

---

## 1. Executive Summary

FIVUCSAS currently stores all tenant biometric data in a shared PostgreSQL instance with row-level security (RLS) for isolation. While sufficient for SaaS customers, enterprise and government tenants — especially under KVKK (Turkey's data protection law) and GDPR — require that biometric data never leave their infrastructure. BYOD (Bring Your Own Database) allows tenants to provide their own PostgreSQL instance with pgvector for biometric storage, while FIVUCSAS manages the application logic, authentication flows, and admin interface. This is analogous to Zimbra (self-hosted email), Bitbucket Server (self-hosted git), or Jira Data Center — the software runs centrally but data resides where the tenant chooses.

---

## 2. Business Context

### Why BYOD

| Stakeholder | Need | BYOD Solution |
|-------------|------|---------------|
| Government agencies | KVKK Article 9: biometric data cannot leave Turkey | Tenant DB in government data center |
| Banks | BDDK regulation: customer data on-premise | Tenant DB in bank's private cloud |
| Hospitals | HIPAA / Saglik Bakanligi: patient data sovereignty | Tenant DB in hospital network |
| Universities | Budget constraints, existing infrastructure | Use existing PostgreSQL cluster |
| Startups (SaaS) | No special requirements | Shared DB (default, unchanged) |

### Competitive Landscape

| Product | Model | BYOD Support |
|---------|-------|-------------|
| Auth0 | SaaS only | No (Enterprise: dedicated tenant, not BYOD) |
| Keycloak | Self-hosted | Full self-host only, no hybrid |
| AWS Rekognition | SaaS only | No |
| **FIVUCSAS** | **Hybrid** | **SaaS default + BYOD option** |

### Revenue Impact

- BYOD is an enterprise upsell: estimated 3-5x price multiplier over standard SaaS
- Enables government and banking contracts that are currently impossible
- Reduces data liability for FIVUCSAS (tenant owns their data)

---

## 3. Architecture Overview

### High-Level Architecture

```
+------------------------------------------------------------------+
|                    FIVUCSAS CENTRAL (Hetzner)                     |
|                                                                   |
|  +------------------+  +------------------+  +-------------------+|
|  | Identity Core    |  | Web Dashboard    |  | Auth Widget       ||
|  | API (Spring Boot)|  | (React)          |  | (verify-app)      ||
|  +--------+---------+  +------------------+  +-------------------+|
|           |                                                       |
|  +--------v---------+                                             |
|  | DataSource Router|                                             |
|  | (TenantAware)    |                                             |
|  +--------+---------+                                             |
|           |                                                       |
|     +-----+------+                                                |
|     |            |                                                |
+-----|------------|------------------------------------------------+
      |            |
      v            v
+----------+  +-----------+  +-----------+  +-----------+
| Shared   |  | Tenant A  |  | Tenant B  |  | Tenant C  |
| DB       |  | DB        |  | DB        |  | DB        |
| (Default)|  | (Bank     |  | (Gov't    |  | (Hospital |
| Hetzner  |  |  Private) |  |  DC)      |  |  AWS)     |
+----------+  +-----------+  +-----------+  +-----------+
  pgvector      pgvector       pgvector       pgvector
```

### Data Partitioning

```
+----------------------------------+----------------------------------+
|       CENTRAL DB (always)        |      TENANT DB (BYOD only)       |
+----------------------------------+----------------------------------+
| tenants                          | face_embeddings                  |
| users (metadata only)            | voice_enrollments                |
| roles, permissions               | nfc_card_enrollments             |
| auth_flows, auth_flow_steps      | biometric_enrollments            |
| auth_sessions (metadata)         | verification_documents           |
| audit_logs (non-biometric)       | verification_sessions            |
| oauth2_clients                   | verification_step_results        |
| tenant_config                    | audit_logs (biometric events)    |
| byod_connections                 | webauthn_credentials             |
+----------------------------------+----------------------------------+

Rule: Raw biometric data (embeddings, images, documents) goes to
      tenant DB. Configuration and non-biometric metadata stays central.
```

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Central DB always holds config | Tenant DB unavailability must not break admin UI |
| Biometric data only in tenant DB | Minimizes what must be routed; config queries stay fast |
| pgvector required on tenant DB | HNSW indexes for face/voice search are non-negotiable |
| Connection per-tenant, not per-request | HikariCP pool per tenant avoids connection storm |
| Tenant provides connection string | FIVUCSAS does not manage tenant infrastructure |

---

## 4. Tenant Configuration Model

### Database Schema Extension

```sql
-- V29 migration: BYOD support
CREATE TABLE byod_connections (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) UNIQUE,
    display_name    VARCHAR(255) NOT NULL,

    -- Connection details (encrypted at rest)
    host            VARCHAR(255) NOT NULL,
    port            INTEGER NOT NULL DEFAULT 5432,
    database_name   VARCHAR(255) NOT NULL,
    username        VARCHAR(255) NOT NULL,
    password_enc    TEXT NOT NULL,            -- AES-256-GCM encrypted

    -- Connection pool settings
    max_pool_size   INTEGER NOT NULL DEFAULT 10,
    min_idle        INTEGER NOT NULL DEFAULT 2,
    conn_timeout_ms INTEGER NOT NULL DEFAULT 30000,

    -- SSL/TLS
    ssl_mode        VARCHAR(20) NOT NULL DEFAULT 'require',
    ssl_ca_cert     TEXT,                     -- PEM-encoded CA certificate
    ssl_client_cert TEXT,                     -- mutual TLS (optional)
    ssl_client_key  TEXT,                     -- mutual TLS (optional)

    -- Health
    status          VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    last_health_at  TIMESTAMP,
    last_error      TEXT,

    -- Metadata
    created_at      TIMESTAMP NOT NULL DEFAULT now(),
    updated_at      TIMESTAMP NOT NULL DEFAULT now()
);

-- Status enum: PENDING, VALIDATING, ACTIVE, DEGRADED, DISCONNECTED, MIGRATING
```

### Tenant Configuration API

```
POST   /api/v1/tenants/{id}/byod          -- Configure BYOD connection
GET    /api/v1/tenants/{id}/byod          -- Get BYOD config (password masked)
PUT    /api/v1/tenants/{id}/byod          -- Update connection details
DELETE /api/v1/tenants/{id}/byod          -- Revert to shared DB
POST   /api/v1/tenants/{id}/byod/test     -- Test connection + validate schema
POST   /api/v1/tenants/{id}/byod/migrate  -- Migrate existing data to BYOD DB
GET    /api/v1/tenants/{id}/byod/health   -- Connection pool + query latency
```

---

## 5. Dynamic DataSource Routing

### Spring Boot Integration

```
+------------------+     +--------------------+     +------------------+
|  HTTP Request    | --> |  TenantContext      | --> |  DataSource      |
|  (JWT has        |     |  Filter             |     |  Router          |
|   tenant_id)     |     |  (sets ThreadLocal) |     |  (AbstractRouting|
+------------------+     +--------------------+     |   DataSource)    |
                                                     +--------+--------+
                                                              |
                                                    +---------+---------+
                                                    |                   |
                                               +----v----+        +----v----+
                                               | Shared  |        | Tenant  |
                                               | Hikari  |        | Hikari  |
                                               | Pool    |        | Pool    |
                                               +---------+        +---------+
```

### Implementation

```java
// Hexagonal: Port
public interface BiometricDataSourcePort {
    DataSource resolveForTenant(UUID tenantId);
    void registerTenantDataSource(UUID tenantId, ByodConnection config);
    void removeTenantDataSource(UUID tenantId);
    HealthStatus checkHealth(UUID tenantId);
}

// Hexagonal: Adapter
@Component
public class DynamicDataSourceRouter extends AbstractRoutingDataSource
    implements BiometricDataSourcePort {

    private final ConcurrentMap<UUID, HikariDataSource> tenantPools =
        new ConcurrentHashMap<>();
    private final HikariDataSource sharedPool;

    @Override
    protected Object determineCurrentLookupKey() {
        return TenantContext.getCurrentTenantId();
    }

    @Override
    protected DataSource determineTargetDataSource() {
        UUID tenantId = TenantContext.getCurrentTenantId();
        if (tenantId == null) return sharedPool;

        HikariDataSource tenantDs = tenantPools.get(tenantId);
        return (tenantDs != null) ? tenantDs : sharedPool;
    }
}
```

### Biometric Repository Split

```java
// Before BYOD: single repository
@Repository
public class FaceEmbeddingRepository {
    private final JdbcTemplate jdbc;  // always shared DB
}

// After BYOD: tenant-aware repository
@Repository
public class FaceEmbeddingRepository {
    private final BiometricDataSourcePort dataSourcePort;

    public List<FaceEmbedding> findByUserId(UUID tenantId, UUID userId) {
        DataSource ds = dataSourcePort.resolveForTenant(tenantId);
        JdbcTemplate jdbc = new JdbcTemplate(ds);
        return jdbc.query("SELECT * FROM face_embeddings WHERE user_id = ?",
            faceEmbeddingMapper, userId);
    }
}
```

---

## 6. Connection Pool Management

### HikariCP Per-Tenant Strategy

```
Central Pool (shared DB):
  - maxPoolSize: 20 (serves config queries for ALL tenants)
  - minIdle: 5
  - connectionTimeout: 10s

Per-Tenant Pool (BYOD DB):
  - maxPoolSize: tenant.max_pool_size (default 10)
  - minIdle: tenant.min_idle (default 2)
  - connectionTimeout: tenant.conn_timeout_ms (default 30s)
  - maxLifetime: 1800000 (30 min)
  - idleTimeout: 600000 (10 min)
```

### Pool Lifecycle

```
Tenant activates BYOD
        |
        v
  [Validate connection]
        |
        v
  [Run schema check: pgvector + required tables]
        |
        v
  [Create HikariDataSource with tenant config]
        |
        v
  [Warm up: min_idle connections]
        |
        v
  [Set status = ACTIVE]
        |
        v
  [Health check every 60s] ----> [DEGRADED if >50% timeout]
        |                                    |
        v                                    v
  [Evict pool after 24h idle]    [Alert admin, retry with backoff]
```

### Resource Limits

| Scenario | Max Tenants | Max Connections | RAM Estimate |
|----------|-------------|-----------------|-------------|
| Small (MVP) | 10 BYOD tenants | 100 (10 x 10) | ~200 MB |
| Medium | 50 BYOD tenants | 500 (50 x 10) | ~1 GB |
| Large | 200 BYOD tenants | 1000 (200 x 5) | ~2 GB |

Current server: CX43 with 16 GB RAM. Biometric-api uses 4 GB. Identity-core-api has ~8 GB headroom, sufficient for medium scale.

---

## 7. Security Architecture

### Credential Management

```
+------------------+     +------------------+     +------------------+
|  Admin enters    | --> |  AES-256-GCM     | --> |  Encrypted in    |
|  DB credentials  |     |  Encryption      |     |  byod_connections|
|  via HTTPS UI    |     |  (per-tenant key)|     |  table           |
+------------------+     +------------------+     +------------------+

Decryption key hierarchy:
  Master Key (env var JWT_SECRET or dedicated BYOD_MASTER_KEY)
    └── Per-tenant key = HKDF(master_key, tenant_id, "byod-v1")
        └── Encrypts: password, ssl_client_key
```

### Tenant Isolation Guarantees

| Threat | Mitigation |
|--------|------------|
| Tenant A queries Tenant B's DB | DataSource routing is per-tenant; no cross-tenant connection possible |
| SQL injection via tenant-provided host | Validate host format (FQDN/IP only), no semicolons, parameterized config |
| Tenant DB compromised | Only biometric data exposed; auth config stays in central DB |
| Man-in-the-middle | SSL mode = "require" minimum; mTLS available |
| Credential leak in logs | Passwords never logged; masked in API responses |
| Central DB compromise | Tenant biometric data not in central DB (BYOD benefit) |

### Schema Validation

Before activating a BYOD connection, the system validates:

1. PostgreSQL version >= 15
2. pgvector extension installed (`CREATE EXTENSION IF NOT EXISTS vector`)
3. Required tables exist (auto-create if missing via Flyway target migration)
4. HNSW indexes present on embedding columns
5. Connection latency < 500ms (P95)
6. SSL certificate valid and trusted

---

## 8. Migration Strategy

### Migrating Existing Tenant from Shared DB to BYOD

```
Phase 1: Setup (admin action)
  |
  +--> Admin configures BYOD connection
  +--> System validates connection + schema
  +--> System creates tables in tenant DB (Flyway subset)
  +--> Status: PENDING -> VALIDATING -> VALIDATED

Phase 2: Data Copy (background job)
  |
  +--> Copy face_embeddings WHERE tenant_id = X
  +--> Copy voice_enrollments WHERE tenant_id = X
  +--> Copy nfc_card_enrollments WHERE tenant_id = X
  +--> Copy verification_documents WHERE tenant_id = X
  +--> Copy webauthn_credentials WHERE tenant_id = X
  +--> Verify row counts match
  +--> Status: VALIDATED -> MIGRATING

Phase 3: Cutover (zero-downtime)
  |
  +--> Enable dual-write: writes go to BOTH shared + tenant DB
  +--> Verify dual-write consistency (5 min observation)
  +--> Switch reads to tenant DB
  +--> Disable writes to shared DB for this tenant
  +--> Status: MIGRATING -> ACTIVE

Phase 4: Cleanup (deferred, admin-triggered)
  |
  +--> Delete tenant's biometric data from shared DB
  +--> Shrink shared DB (VACUUM FULL on affected tables)
  +--> Status: ACTIVE (cleanup complete)
```

### Rollback Plan

At any point before Phase 4 cleanup, the admin can revert:

1. Switch reads back to shared DB
2. Replay any writes that went to tenant DB during dual-write
3. Remove tenant pool
4. Set status = DISCONNECTED

---

## 9. Implementation Phases

### Phase 1 — Foundation (3 weeks)

| Task | Effort | Details |
|------|--------|---------|
| V29 Flyway migration (byod_connections table) | 1 day | Schema as defined above |
| ByodConnection entity + repository | 1 day | JPA entity with encrypted fields |
| BiometricDataSourcePort interface | 1 day | Hexagonal port definition |
| DynamicDataSourceRouter | 3 days | AbstractRoutingDataSource + HikariCP pool management |
| TenantContext ThreadLocal filter | 1 day | Extract tenant_id from JWT, set ThreadLocal |
| BYOD admin API (6 endpoints) | 2 days | CRUD + test + health |
| Credential encryption service | 2 days | AES-256-GCM with per-tenant key derivation |
| Schema validation service | 2 days | pgvector check, table creation, index verification |
| Unit tests | 2 days | Pool lifecycle, routing, encryption |

### Phase 2 — Repository Refactor (2 weeks)

| Task | Effort | Details |
|------|--------|---------|
| Split biometric repositories | 3 days | Face, voice, NFC, verification, WebAuthn repositories become tenant-aware |
| Biometric-processor BYOD proxy | 3 days | Python service queries correct DB based on tenant header |
| Integration tests | 2 days | TestContainers with 2 PostgreSQL instances |
| Admin UI: BYOD configuration page | 2 days | Connection form, health dashboard, migration trigger |

### Phase 3 — Migration Engine (2 weeks)

| Task | Effort | Details |
|------|--------|---------|
| Background migration job | 3 days | Spring Batch or custom with progress tracking |
| Dual-write interceptor | 2 days | Write to both DBs during cutover |
| Consistency verifier | 2 days | Row count + checksum comparison |
| Rollback mechanism | 1 day | Revert to shared DB |
| Migration admin UI | 2 days | Progress bar, logs, rollback button |

### Phase 4 — Hardening (1 week)

| Task | Effort | Details |
|------|--------|---------|
| Connection health monitor | 1 day | 60s health check, alert on DEGRADED |
| Pool eviction policy | 1 day | Remove idle pools after 24h |
| Load testing | 2 days | 50 concurrent BYOD tenants |
| Documentation | 1 day | Tenant setup guide, requirements checklist |

### Total Effort: ~8 weeks

```
Week 1-3:   Phase 1 (Foundation — routing, pools, encryption)
Week 4-5:   Phase 2 (Repository refactor, biometric-processor proxy)
Week 6-7:   Phase 3 (Migration engine, dual-write, cutover)
Week 8:     Phase 4 (Hardening, monitoring, documentation)
```

---

## 10. Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Tenant DB latency spikes (remote DC) | High | Medium | Connection timeout limits + circuit breaker pattern |
| Tenant DB goes offline | Medium | High | Graceful degradation: queue writes, serve cached reads |
| Pool exhaustion under load | Medium | High | Per-tenant pool limits + global connection ceiling |
| Schema drift (tenant modifies tables) | Low | High | Schema version check on health probe; alert + block if incompatible |
| Credential rotation coordination | Medium | Medium | API for credential update; connection pool refresh without restart |
| Migration data loss | Low | Critical | Checksum verification + dual-write before cutover + rollback |
| Cross-tenant data leak via routing bug | Low | Critical | Integration tests with 2 DBs; audit logs on every biometric query |
| Increased operational complexity | High | Medium | Comprehensive monitoring dashboard; tenant self-service where possible |

---

## 11. Dependencies and Prerequisites

### Technical Prerequisites

| Prerequisite | Status | Notes |
|-------------|--------|-------|
| Row-level security (RLS) | Implemented | Currently provides isolation in shared DB |
| pgvector extension | Deployed | Required on every tenant DB |
| AES-256 encryption utility | Exists | Used for JWT; extend for BYOD credentials |
| Flyway migrations | V1-V28 | BYOD requires subset migration runner for tenant DBs |
| Spring AbstractRoutingDataSource | Available | Spring Boot built-in |
| HikariCP | In use | Already the connection pool; extend for multi-pool |

### Infrastructure Prerequisites

| Prerequisite | Status | Notes |
|-------------|--------|-------|
| Tenant DB must be reachable from Hetzner | Tenant responsibility | Public IP or VPN tunnel |
| PostgreSQL >= 15 on tenant DB | Tenant responsibility | Required for pgvector 0.5+ |
| SSL certificate on tenant DB | Tenant responsibility | Self-signed OK if CA cert provided |
| Network bandwidth: Hetzner <-> tenant DB | Variable | Should be <50ms latency for acceptable UX |

### Organizational Prerequisites

- Legal: BYOD contract template (data processing agreement)
- Support: Tenant onboarding runbook for BYOD setup
- Pricing: Enterprise tier pricing model that includes BYOD

---

*This document defines the target architecture. Implementation should begin only after at least one enterprise customer confirms BYOD as a requirement. The shared-DB model with RLS is sufficient for all current tenants.*
