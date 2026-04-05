# BaaS Per-Feature API Rental Model

**Version:** 1.0
**Date:** 2026-04-05
**Status:** Design Document (Pre-Implementation)
**Author:** Ahmet Abdullah Gultekin
**Project:** FIVUCSAS - Face and Identity Verification Using Cloud-Based SaaS
**Organization:** Marmara University - Computer Engineering Department
**Feature ID:** W19

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Business Model](#2-business-model)
3. [Competitor Analysis](#3-competitor-analysis)
4. [API Gateway Architecture](#4-api-gateway-architecture)
5. [Feature Isolation and Packaging](#5-feature-isolation-and-packaging)
6. [Usage Metering and Billing](#6-usage-metering-and-billing)
7. [SDK Distribution](#7-sdk-distribution)
8. [Developer Experience](#8-developer-experience)
9. [Implementation Phases](#9-implementation-phases)
10. [Risk Assessment](#10-risk-assessment)
11. [Dependencies and Prerequisites](#11-dependencies-and-prerequisites)

---

## 1. Executive Summary

FIVUCSAS has evolved from a university project into a production-grade biometric platform with 10 authentication methods, identity verification, and an embeddable auth widget. The next commercial step is offering individual biometric capabilities as rentable APIs -- Biometrics as a Service (BaaS). Developers should be able to sign up, get an API key, and call `POST /v1/face/verify` without deploying any infrastructure. This document defines the pricing tiers (Free/Developer/Enterprise), API gateway architecture with per-key rate limiting, feature isolation model, usage metering pipeline, SDK distribution strategy (npm, Maven Central, CocoaPods), and developer portal experience. The target is to make FIVUCSAS as easy to integrate as Stripe is for payments.

---

## 2. Business Model

### Pricing Tiers

```
+------------------------------------------------------------------+
|                    FIVUCSAS BaaS Pricing                          |
+------------------------------------------------------------------+
|                                                                   |
|  FREE              DEVELOPER           ENTERPRISE                 |
|  $0/month          $29/month           Custom                     |
|                                                                   |
|  100 API calls     10,000 API calls    Unlimited                  |
|  Face only         All features        All features               |
|  1 API key         5 API keys          Unlimited keys             |
|  Community support Email support       Dedicated support          |
|  No SLA            99.5% uptime SLA    99.9% uptime SLA          |
|  48h data retention 90d data retention Custom retention           |
|  Watermarked       No watermark        White-label                |
|  5 req/min         60 req/min          Custom rate limit          |
|                                        BYOD option                |
|                                        On-premise deployment      |
|                                        SSO/SAML integration       |
|                                                                   |
+------------------------------------------------------------------+
```

### Feature Pricing (a la carte, Developer tier and above)

| Feature | Per-Call Cost | Included in Developer | Description |
|---------|-------------|----------------------|-------------|
| Face Detect | $0.001 | 10,000 | Bounding box + landmarks |
| Face Verify (1:1) | $0.003 | 3,333 | Compare two faces |
| Face Search (1:N) | $0.005 | 2,000 | Find in gallery |
| Face Enroll | $0.002 | 5,000 | Add to gallery |
| Voice Verify | $0.004 | 2,500 | Speaker verification |
| Voice STT Verify | $0.006 | 1,666 | Speaker + content |
| Card Detect | $0.003 | 3,333 | Document detection + crop |
| OCR Extract | $0.005 | 2,000 | TC Kimlik field extraction |
| Liveness Check | $0.004 | 2,500 | Anti-spoofing |
| NFC Verify | $0.005 | 2,000 | Chip authentication |
| Full Verification Flow | $0.05 | 200 | Multi-step identity verification |

### Revenue Projections (Conservative)

| Month | Free Users | Dev Users | Enterprise | MRR |
|-------|-----------|-----------|------------|-----|
| 1 | 50 | 5 | 0 | $145 |
| 3 | 200 | 20 | 1 | $1,580 |
| 6 | 500 | 50 | 3 | $4,450+ |
| 12 | 1,000 | 100 | 10 | $12,900+ |

---

## 3. Competitor Analysis

### Market Positioning

```
                    High Accuracy
                         |
                         |
          AWS Rekognition o         o Azure Face API
                         |
                         |
     FIVUCSAS o----------+---------------------------o Auth0
     (multi-modal,       |                    (auth only,
      affordable)        |                     no biometrics)
                         |
          Onfido o       |
                         |
                    Low Accuracy

     <-- Low Cost                      High Cost -->
```

### Detailed Comparison

| Feature | FIVUCSAS BaaS | AWS Rekognition | Azure Face | Auth0 | Onfido |
|---------|-------------|-----------------|-----------|-------|--------|
| Face verify | Yes | Yes | Yes | No | Yes |
| Voice biometrics | Yes | No | Speaker Recognition | No | No |
| NFC document | Yes | No | No | No | Yes |
| Card OCR | Yes | No (use Textract) | No (use Form Recognizer) | No | Yes |
| Identity verification | Yes | No | No | No | Yes |
| Auth flows | Yes | No | No | Yes | No |
| Embeddable widget | Yes | No | No | Yes (Lock) | Yes |
| Multi-modal fusion | Yes | No | No | No | Partial |
| On-premise option | Yes (BYOD) | No | No | No | No |
| Free tier | 100 calls | 5,000/mo (12 months) | 30,000/mo | 7,000 users | None |
| Face verify cost | $0.003 | $0.001 | $0.001 | N/A | $0.10+ |
| Turkish ID support | Native | No | No | No | Yes |
| KVKK compliance | Native | No | No | No | Partial |

### Unique Value Proposition

1. **Multi-modal in one API**: Face + Voice + NFC + Card + Liveness -- competitors require multiple services
2. **Turkish-first**: Native TC Kimlik support, Turkish voice STT, KVKK compliance
3. **Full stack**: From biometric capture to identity verification to auth flows -- one vendor
4. **Affordable**: 3x cheaper than Onfido for full verification flows
5. **On-premise option**: BYOD for enterprise, impossible with pure SaaS competitors

---

## 4. API Gateway Architecture

### System Architecture

```
+------------------------------------------------------------------+
|                     INTERNET                                      |
+------------------------------------------------------------------+
           |
           v
+----------+---------------------------------------------------+
|  API Gateway (Traefik + Custom Middleware)                    |
|                                                               |
|  +------------------+  +------------------+  +--------------+ |
|  | API Key          |  | Rate Limiter     |  | Usage        | |
|  | Validator        |  | (per-key,        |  | Meter        | |
|  | (Redis lookup)   |  |  sliding window) |  | (Redis -> PG)| |
|  +--------+---------+  +--------+---------+  +------+-------+ |
|           |                     |                    |         |
|  +--------v---------+  +-------v--------+  +--------v-------+ |
|  | Feature Gate     |  | Quota Check    |  | Response       | |
|  | (allowed APIs    |  | (calls left    |  | Transformer    | |
|  |  per plan)       |  |  this period)  |  | (watermark)    | |
|  +------------------+  +----------------+  +----------------+ |
|                                                               |
+---+---------------------------+---------------------------+---+
    |                           |                           |
    v                           v                           v
+---+-------+           +------+------+           +--------+----+
| Identity  |           | Biometric   |           | Biometric   |
| Core API  |           | Processor   |           | Processor   |
| (auth,    |           | (face,      |           | (voice,     |
|  flows)   |           |  liveness)  |           |  card, NFC) |
+-----------+           +-------------+           +-------------+
```

### API Key Schema

```sql
-- V30 migration: BaaS API keys
CREATE TABLE api_keys (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id),
    key_hash        VARCHAR(64) NOT NULL UNIQUE,   -- SHA-256 of API key
    key_prefix      VARCHAR(12) NOT NULL,           -- "fvcs_live_" or "fvcs_test_"
    name            VARCHAR(255) NOT NULL,
    plan            VARCHAR(20) NOT NULL DEFAULT 'FREE',
    status          VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',

    -- Permissions
    allowed_features TEXT[] NOT NULL DEFAULT '{"face_detect"}',
    rate_limit_rpm   INTEGER NOT NULL DEFAULT 5,

    -- Quota
    monthly_quota    INTEGER NOT NULL DEFAULT 100,
    current_usage    INTEGER NOT NULL DEFAULT 0,
    quota_reset_at   TIMESTAMP NOT NULL,

    -- Metadata
    last_used_at     TIMESTAMP,
    created_at       TIMESTAMP NOT NULL DEFAULT now(),
    expires_at       TIMESTAMP
);

CREATE TABLE api_usage_log (
    id              BIGSERIAL PRIMARY KEY,
    api_key_id      UUID NOT NULL REFERENCES api_keys(id),
    endpoint        VARCHAR(255) NOT NULL,
    feature         VARCHAR(50) NOT NULL,
    status_code     INTEGER NOT NULL,
    latency_ms      INTEGER NOT NULL,
    request_size    INTEGER,
    response_size   INTEGER,
    ip_address      INET,
    created_at      TIMESTAMP NOT NULL DEFAULT now()
);

-- Partitioned by month for efficient cleanup
CREATE INDEX idx_usage_log_key_date ON api_usage_log (api_key_id, created_at);
```

### API Key Format

```
fvcs_live_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6
fvcs_test_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6
|    |     |
|    |     +-- 36 random hex chars (144-bit entropy)
|    +-- environment (live = production, test = sandbox)
+-- prefix (always "fvcs")
```

### Rate Limiting Implementation

```
Algorithm: Sliding Window (Redis sorted set)

Key:    rate:{api_key_id}:{minute}
Value:  Sorted set of request timestamps

For each request:
  1. ZREMRANGEBYSCORE key 0 (now - 60s)     // Remove old entries
  2. count = ZCARD key                       // Count in window
  3. If count >= rate_limit_rpm: return 429
  4. ZADD key now now                        // Add this request
  5. EXPIRE key 120                          // Cleanup safety net
```

---

## 5. Feature Isolation and Packaging

### Feature Bundles

```
+------------------------------------------------------------------+
|                    FEATURE BUNDLES                                 |
+------------------------------------------------------------------+
|                                                                   |
|  FACE BUNDLE            VOICE BUNDLE          IDENTITY BUNDLE     |
|  +-----------------+    +-----------------+   +-----------------+ |
|  | face/detect     |    | voice/enroll    |   | verify/start    | |
|  | face/enroll     |    | voice/verify    |   | verify/status   | |
|  | face/verify     |    | voice/search    |   | verify/document | |
|  | face/search     |    | voice/stt       |   | verify/nfc      | |
|  | face/liveness   |    | voice/challenge |   | verify/face     | |
|  | face/quality    |    +-----------------+   | verify/liveness | |
|  +-----------------+                          +-----------------+ |
|                                                                   |
|  CARD BUNDLE            AUTH BUNDLE           FULL STACK          |
|  +-----------------+    +-----------------+   +-----------------+ |
|  | card/detect     |    | auth/flow       |   | All features    | |
|  | card/ocr        |    | auth/session    |   | (face + voice   | |
|  | card/mrz        |    | auth/widget     |   |  + card + auth  | |
|  +-----------------+    | auth/oauth      |   |  + verify)      | |
|                         +-----------------+   +-----------------+ |
+------------------------------------------------------------------+
```

### API Namespace

All BaaS endpoints under `/baas/v1/`:

```
POST   /baas/v1/face/detect        { image: base64 }
POST   /baas/v1/face/verify        { image1: base64, image2: base64 }
POST   /baas/v1/face/enroll        { image: base64, gallery_id: "...", person_id: "..." }
POST   /baas/v1/face/search        { image: base64, gallery_id: "...", top_k: 5 }
POST   /baas/v1/face/liveness      { image: base64 }
POST   /baas/v1/face/quality       { image: base64 }

POST   /baas/v1/voice/enroll       { audio: base64, person_id: "..." }
POST   /baas/v1/voice/verify       { audio: base64, person_id: "..." }
POST   /baas/v1/voice/challenge    { language: "tr" }
POST   /baas/v1/voice/verify-stt   { audio: base64, passphrase_id: "...", person_id: "..." }

POST   /baas/v1/card/detect        { image: base64 }
POST   /baas/v1/card/ocr           { image: base64, document_type: "tc_kimlik" }
POST   /baas/v1/card/mrz           { image: base64 }

POST   /baas/v1/verify/start       { template: "banking_kyc", person_id: "..." }
GET    /baas/v1/verify/{session_id} 
POST   /baas/v1/verify/{session_id}/step
```

### Gallery Management (Face/Voice)

```
POST   /baas/v1/galleries                    -- Create gallery
GET    /baas/v1/galleries                    -- List galleries
DELETE /baas/v1/galleries/{id}               -- Delete gallery
GET    /baas/v1/galleries/{id}/persons       -- List persons
DELETE /baas/v1/galleries/{id}/persons/{pid} -- Remove person
```

---

## 6. Usage Metering and Billing

### Metering Pipeline

```
API Request
     |
     v
+------------------+     +------------------+     +-------------------+
| Redis Counter    | --> | Flush to PG      | --> | Monthly           |
| (real-time,      |     | (every 5 min,    |     | Aggregation       |
|  per-key atomic  |     |  batch insert)   |     | (cron job,        |
|  increment)      |     |                  |     |  invoice gen)     |
+------------------+     +------------------+     +-------------------+
                                                          |
                                                          v
                                                  +-------------------+
                                                  | Billing Provider  |
                                                  | (Stripe/Iyzico)  |
                                                  +-------------------+
```

### Usage Tracking

```python
# Redis keys for real-time metering
usage:{api_key_id}:2026-04:total        -> atomic counter (monthly total)
usage:{api_key_id}:2026-04:face_verify  -> atomic counter (per-feature)
usage:{api_key_id}:2026-04:voice_verify -> atomic counter (per-feature)
quota:{api_key_id}:remaining            -> monthly quota remaining (decrement)
```

### Invoice Schema

```json
{
  "invoice_id": "inv_2026_04_abc123",
  "tenant_id": "...",
  "period": "2026-04",
  "plan": "DEVELOPER",
  "base_price": 29.00,
  "usage": {
    "face_verify": { "count": 8500, "included": 3333, "overage": 5167, "cost": 15.50 },
    "voice_verify": { "count": 1200, "included": 2500, "overage": 0, "cost": 0.00 },
    "card_ocr": { "count": 500, "included": 2000, "overage": 0, "cost": 0.00 }
  },
  "overage_total": 15.50,
  "total": 44.50,
  "currency": "USD"
}
```

---

## 7. SDK Distribution

### SDK Matrix

| Platform | Package | Repository | Language |
|----------|---------|-----------|----------|
| JavaScript/TypeScript | `@fivucsas/sdk` | npm | TypeScript |
| Java/Kotlin (Android) | `com.fivucsas:sdk` | Maven Central | Kotlin |
| Swift (iOS) | `FivucsasSDK` | CocoaPods / SPM | Swift |
| Python | `fivucsas` | PyPI | Python |
| cURL/REST | N/A (docs only) | N/A | Any |

### JavaScript SDK Example

```typescript
import { FivucsasClient } from '@fivucsas/sdk';

const client = new FivucsasClient({
  apiKey: 'fvcs_live_...',
  region: 'eu',  // or 'tr' for Turkey
});

// Face verification
const result = await client.face.verify({
  image1: file1,  // File, Blob, or base64
  image2: file2,
});
console.log(result.match, result.confidence); // true, 0.92

// Voice verification with STT
const challenge = await client.voice.challenge({ language: 'tr' });
console.log('Say:', challenge.text); // "yedi kirmizi balon uctu"

const voiceResult = await client.voice.verifyStt({
  audio: audioBlob,
  passphraseId: challenge.id,
  personId: 'user_123',
});

// Identity verification flow
const session = await client.verify.start({
  template: 'banking_kyc',
  personId: 'user_123',
});
// Returns step-by-step instructions...
```

### Android SDK Example

```kotlin
val client = FivucsasClient.Builder()
    .apiKey("fvcs_live_...")
    .region("eu")
    .build()

// Face verification
val result = client.face.verify(
    image1 = bitmap1,
    image2 = bitmap2
)
Log.d("FIVUCSAS", "Match: ${result.match}, Score: ${result.confidence}")
```

### SDK Architecture (shared core)

```
+------------------------------------------------------------------+
|  @fivucsas/sdk-core (TypeScript, platform-agnostic)              |
|                                                                   |
|  +------------------+  +------------------+  +------------------+ |
|  | HTTP Client      |  | Auth (API key)   |  | Retry + Circuit | |
|  | (fetch/axios)    |  |                  |  | Breaker         | |
|  +------------------+  +------------------+  +------------------+ |
|  +------------------+  +------------------+  +------------------+ |
|  | Face Module      |  | Voice Module     |  | Card Module     | |
|  +------------------+  +------------------+  +------------------+ |
|  +------------------+  +------------------+                       |
|  | Verify Module    |  | Auth Module      |                       |
|  +------------------+  +------------------+                       |
+------------------------------------------------------------------+
         |                    |                    |
         v                    v                    v
   @fivucsas/sdk       com.fivucsas:sdk     FivucsasSDK
   (npm)               (Maven Central)      (CocoaPods)
```

---

## 8. Developer Experience

### Developer Portal Features

```
+------------------------------------------------------------------+
|  DEVELOPER PORTAL (already scaffolded at /developer-portal)       |
+------------------------------------------------------------------+
|                                                                   |
|  Dashboard                                                        |
|  +------------------+  +------------------+  +------------------+ |
|  | API Keys         |  | Usage Graph      |  | Quick Start      | |
|  | [Create] [Revoke]|  | (daily/monthly)  |  | (copy-paste code)| |
|  +------------------+  +------------------+  +------------------+ |
|                                                                   |
|  Documentation                                                    |
|  +------------------+  +------------------+  +------------------+ |
|  | API Reference    |  | SDK Guides       |  | Code Examples    | |
|  | (OpenAPI/Swagger)|  | (JS/Android/iOS) |  | (by use case)   | |
|  +------------------+  +------------------+  +------------------+ |
|                                                                   |
|  Testing                                                          |
|  +------------------+  +------------------+  +------------------+ |
|  | API Playground   |  | Test API Keys    |  | Webhook Tester   | |
|  | (try it live)    |  | (sandbox env)    |  | (event inspector)| |
|  +------------------+  +------------------+  +------------------+ |
|                                                                   |
|  Account                                                          |
|  +------------------+  +------------------+  +------------------+ |
|  | Billing          |  | Team Members     |  | Webhooks Config  | |
|  | (invoices, plan) |  | (RBAC)           |  | (event URLs)     | |
|  +------------------+  +------------------+  +------------------+ |
+------------------------------------------------------------------+
```

### Onboarding Flow (Time to First API Call: <5 minutes)

```
1. Sign up (email + password or GitHub OAuth)
         |
2. Get test API key (instant, no credit card)
         |
3. Copy code snippet from Quick Start
         |
4. Make first API call (sandbox, watermarked)
         |
5. See result in dashboard
         |
6. Upgrade to Developer ($29/mo) for production key
```

### API Playground

Interactive API tester in the browser:

```
+----------------------------------------------+
|  POST /baas/v1/face/verify                   |
+----------------------------------------------+
|                                              |
|  API Key: [fvcs_test_...      ] [Auto-fill]  |
|                                              |
|  Image 1: [Upload] or [Webcam]               |
|  Image 2: [Upload] or [Webcam]               |
|                                              |
|  [ Try It ]                                  |
|                                              |
|  Response (243ms):                           |
|  {                                           |
|    "match": true,                            |
|    "confidence": 0.924,                      |
|    "model": "arcface-512d",                  |
|    "processing_time_ms": 243                 |
|  }                                           |
+----------------------------------------------+
```

---

## 9. Implementation Phases

### Phase 1 — API Gateway + Keys (3 weeks)

| Task | Effort | Details |
|------|--------|---------|
| V30 migration (api_keys, api_usage_log) | 1 day | Schema as defined |
| API key generation + management service | 2 days | Create, revoke, rotate |
| API key validation middleware | 2 days | Redis-cached key lookup, feature gate |
| Rate limiter (sliding window) | 2 days | Redis sorted set implementation |
| /baas/v1/ endpoint namespace | 3 days | Proxy to existing biometric-processor + identity-core |
| Usage counter (Redis + flush to PG) | 2 days | Atomic increment, batch flush |
| Admin UI: API key management | 2 days | Extend DeveloperPortalPage |
| Tests | 1 day | Rate limiting, quota, key validation |

### Phase 2 — Feature Isolation + Metering (2 weeks)

| Task | Effort | Details |
|------|--------|---------|
| Feature bundles configuration | 2 days | Plan -> allowed features mapping |
| Per-feature usage tracking | 2 days | Breakdown by endpoint |
| Quota enforcement + 429 responses | 1 day | Reject when quota exhausted |
| Gallery management endpoints | 3 days | Per-tenant face/voice galleries |
| Usage dashboard (React) | 2 days | Charts, daily/monthly breakdown |

### Phase 3 — SDKs (3 weeks)

| Task | Effort | Details |
|------|--------|---------|
| @fivucsas/sdk-core (TypeScript) | 3 days | HTTP client, auth, retry, modules |
| @fivucsas/sdk (npm package) | 2 days | Browser + Node.js wrapper |
| com.fivucsas:sdk (Kotlin) | 3 days | OkHttp client, Kotlin coroutines |
| FivucsasSDK (Swift) | 3 days | URLSession, async/await |
| fivucsas (Python) | 2 days | requests/httpx, typed responses |
| SDK documentation + examples | 2 days | Per-platform quick start |

### Phase 4 — Billing + Developer Portal (2 weeks)

| Task | Effort | Details |
|------|--------|---------|
| Stripe/Iyzico integration | 3 days | Subscription + overage billing |
| Invoice generation | 2 days | Monthly aggregation + PDF |
| Developer portal enhancement | 3 days | API playground, usage graphs, team management |
| API reference (OpenAPI 3.0) | 2 days | Auto-generated from endpoint definitions |

### Phase 5 — Launch Preparation (1 week)

| Task | Effort | Details |
|------|--------|---------|
| Sandbox environment | 2 days | Test keys with mock data |
| Onboarding email sequence | 1 day | Welcome, quick start, upgrade prompt |
| Landing page update | 1 day | Pricing page, "Get Started" CTA |
| Load testing | 1 day | 1000 concurrent API keys, rate limiting under load |

### Total Effort: ~11 weeks

```
Week 1-3:    Phase 1 (API Gateway, keys, rate limiting)
Week 4-5:    Phase 2 (Feature isolation, metering, dashboard)
Week 6-8:    Phase 3 (SDKs: JS, Kotlin, Swift, Python)
Week 9-10:   Phase 4 (Billing integration, developer portal)
Week 11:     Phase 5 (Launch preparation)
```

---

## 10. Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Low initial adoption (chicken-and-egg) | High | Medium | Generous free tier; target university/hackathon communities first |
| API abuse (scraping, DDoS via free tier) | High | High | Rate limiting, CAPTCHA on signup, IP reputation, anomaly detection |
| Cost of compute exceeds revenue (free tier) | Medium | High | Free tier limited to face-only (lightest compute); monitor cost/call |
| SDK maintenance burden (4 platforms) | Medium | Medium | TypeScript core with thin platform wrappers; auto-generate from OpenAPI |
| Billing integration complexity | Medium | Medium | Start with Stripe (global) + Iyzico (Turkey); defer custom invoicing |
| Competitor price war | Low | Medium | Compete on features (multi-modal), not price; Turkish market lock-in |
| Security: API key leaked in client code | High | High | Docs emphasize server-side only; test keys clearly marked; key rotation API |
| Scaling beyond single Hetzner server | Medium | High | Horizontal scaling plan (Phase 5+); BYOD offloads enterprise tenants |

---

## 11. Dependencies and Prerequisites

### Technical Prerequisites

| Prerequisite | Status | Notes |
|-------------|--------|-------|
| OAuth2 endpoints | Implemented | V24 migration, OAuth2Controller |
| DeveloperPortalPage | Scaffolded | Needs enhancement for BaaS |
| Traefik API gateway | Running | Add middleware for API key validation |
| Redis | Running | Rate limiting + usage counters |
| Biometric endpoints | All operational | 46+ endpoints in biometric-processor |
| Auth widget | Deployed | Embeddable widget for auth flows |

### Business Prerequisites

| Prerequisite | Status | Notes |
|-------------|--------|-------|
| Legal: Terms of Service for API | Not created | Required before public launch |
| Legal: Data Processing Agreement | Not created | Required for KVKK/GDPR |
| Payment processor account | Not created | Stripe (international) + Iyzico (Turkey) |
| Support system | Not created | Zendesk/Freshdesk or email-based initially |
| Marketing website | Exists (landing page) | Needs pricing page + developer docs section |

### Infrastructure Scaling Plan

| Users | Current (CX43) | Needed | Action |
|-------|----------------|--------|--------|
| 0-100 | 8 CPU, 16 GB | Sufficient | No change |
| 100-500 | Stretched | CX43 + dedicated biometric worker | Add second VPS |
| 500-2000 | Insufficient | Kubernetes cluster | Migrate to k3s or managed k8s |
| 2000+ | N/A | Multi-region | Hetzner EU + US East |

---

*The BaaS model transforms FIVUCSAS from a deployed product into a platform. Start with the API gateway and free tier to validate demand before investing in billing and SDKs. The existing DeveloperPortalPage and auth widget provide a head start on developer experience.*
