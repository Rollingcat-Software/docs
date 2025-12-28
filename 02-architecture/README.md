# FIVUCSAS Architecture Documentation

System architecture, design decisions, and architectural diagrams.

**Last Updated:** December 28, 2025

---

## Key Documents

### Architecture & Design
- **[MODULE_STRUCTURE.md](MODULE_STRUCTURE.md)** - ⭐ Official module structure and organization (NEW)
- **[ARCHITECTURE_DIAGRAMS.md](ARCHITECTURE_DIAGRAMS.md)** - ⭐ Mermaid diagrams for SE (NEW)
- **[ARCHITECTURE_ANALYSIS.md](ARCHITECTURE_ANALYSIS.md)** - Comprehensive architecture analysis
- **[SYSTEM_DESIGN_ANALYSIS_AND_DECISION.md](SYSTEM_DESIGN_ANALYSIS_AND_DECISION.md)** - Design decisions

### Audits & Reports
- **[PROJECT_DESIGN_AUDIT.md](PROJECT_DESIGN_AUDIT.md)** - Design audit report
- **[DESIGN_AUDIT_REPORT.md](DESIGN_AUDIT_REPORT.md)** - Detailed audit findings
- **[PROJECT_DESIGN_AND_STATUS_ANALYSIS.md](PROJECT_DESIGN_AND_STATUS_ANALYSIS.md)** - Design and status analysis

---

## Diagrams

### Mermaid Diagrams (Software Engineering)
See **[ARCHITECTURE_DIAGRAMS.md](ARCHITECTURE_DIAGRAMS.md)** for:
- System Architecture Overview
- Module Structure
- Component Diagrams
- Deployment Diagrams
- Data Flow Diagrams
- Sequence Diagrams
- Class Diagrams
- State Diagrams
- Entity Relationship Diagram
- Use Case Diagram

### PlantUML Diagrams
See [diagrams/](diagrams/) folder for 35+ professional UML diagrams:
- Entity-Relationship (ER) diagrams
- Use case diagrams (end-user, admin, external systems)
- Activity diagrams (enrollment, verification, tenant management)
- State machine diagrams (user, session, verification)
- Deployment diagrams (development, Kubernetes, HA, multi-region)
- Network architecture diagrams
- Security architecture diagrams

---

## Module Overview

```
FIVUCSAS/
├── biometric-processor/   # FastAPI ML Service (100%)
├── identity-core-api/     # Spring Boot API (68%)
├── web-app/               # React Admin Dashboard (100%)
├── client-apps/           # KMP Cross-Platform (60%)
│   ├── shared/            # 90% shared code
│   ├── androidApp/        # Android
│   └── desktopApp/        # Desktop (Win/Linux/macOS)
├── docs/                  # Documentation
└── practice-and-test/     # NFC Readers, Experiments
```

See [MODULE_STRUCTURE.md](MODULE_STRUCTURE.md) for detailed module definitions.

---

## Architecture Patterns

FIVUCSAS follows:
- **Hexagonal Architecture** (Ports and Adapters)
- **Microservices Architecture**
- **SOLID Principles**
- **Clean Architecture** with separation of concerns
- **Domain-Driven Design (DDD)**
- **MVVM Pattern** for presentation layer
- **Repository Pattern** for data access

---

## Technology Stack

| Layer | Technology | Status |
|-------|------------|--------|
| **Backend API** | Spring Boot 3.2 (Java 21) | ⚠️ 68% |
| **ML Service** | FastAPI (Python 3.11) | ✅ 100% |
| **Web Dashboard** | React 18, TypeScript, Material-UI | ✅ 100% |
| **Mobile/Desktop** | Kotlin Multiplatform, Compose | ⚠️ 60% |
| **Database** | PostgreSQL 16 + pgvector | ✅ 100% |
| **Cache/Queue** | Redis 7 | ✅ Ready |
| **API Gateway** | NGINX | ✅ Ready |

---

## Related Documentation

- [Development Guide](../03-development/CLAUDE.md) - Implementation details
- [API Documentation](../04-api/) - API specifications
- [Testing Guide](../05-testing/) - Testing strategy
- [Deployment Guide](../06-deployment/) - Deployment instructions

---

[← Back to Main Documentation](../README.md)
