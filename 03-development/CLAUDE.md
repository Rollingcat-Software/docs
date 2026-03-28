# CLAUDE.md — FIVUCSAS Development Documentation

This file provides guidance to Claude Code when working with the FIVUCSAS documentation submodule.

## Project Overview

**FIVUCSAS** (Face and Identity Verification Using Cloud-based SaaS) is a multi-tenant biometric authentication platform developed as an Engineering Project at Marmara University's Computer Engineering Department.

**Current Status (~98% Complete, March 2026):**
- Identity Core API: Production (Spring Boot 3.2.0, Java 21, Maven)
- Biometric Processor: Production (FastAPI, Python 3.11+, DeepFace + Resemblyzer)
- Web Dashboard: Production (React 18 + TypeScript 5 + Vite 8)
- Client Apps: 75% (Kotlin Multiplatform — Android APK green, Desktop working, iOS stub)
- Embeddable Auth Widget: 75% (verify-app, auth-js SDK, auth-react done; Web Components remaining)
- All 10 auth methods production-ready
- 304 unit tests (Vitest), 276+ E2E tests (Playwright), 528 backend tests

## Architecture Principles

- **Hexagonal Architecture** (Ports and Adapters) across all services
- **SOLID, DRY, KISS, YAGNI** strictly enforced
- **Clean Architecture** with clear separation of concerns

## Documentation Structure

```
docs/
├── 01-project/          # Project overview, team, timeline
├── 02-architecture/     # System architecture, diagrams, module structure
├── 03-development/      # Development guides, setup, coding standards
├── 04-api/              # API documentation, integration guides
├── 05-deployment/       # Deployment guides, infrastructure
├── 06-testing/          # Test plans, reports
├── 07-status/           # Implementation status reports
├── 08-presentation/     # Presentation materials
└── 09-auth-flows/       # Multi-modal auth system architecture (10 documents)
```

## Deployment

- **Server**: Hetzner CX43 (8 vCPU, 16GB RAM, 150GB disk)
- **CI/CD**: GitHub Actions on self-hosted runner `hetzner-cx43`
- **Identity Core API**: https://auth.rollingcatsoftware.com
- **Web Dashboard**: https://ica-fivucsas.rollingcatsoftware.com (Hostinger)
- **Biometric API**: Internal on Hetzner (port 8001)
- **Shared infra**: PostgreSQL 17 + pgvector, Redis 7.4
