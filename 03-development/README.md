# Development Documentation

Guides for developers working on the FIVUCSAS platform.

## Essential Reading

**START HERE:** [CLAUDE.md](CLAUDE.md) - Main developer guide with:
- Project overview and current status
- Architecture principles (SOLID, Clean Architecture, DRY, KISS, YAGNI)
- Repository structure
- Development workflow for each component
- Common development tasks
- Key design patterns used
- Critical conventions
- Troubleshooting guides

## Documents

| File | Description |
|------|-------------|
| [CLAUDE.md](CLAUDE.md) | Main developer guide - START HERE |
| [KOTLIN_MULTIPLATFORM_GUIDE.md](KOTLIN_MULTIPLATFORM_GUIDE.md) | Mobile/desktop app development |
| [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) | Complete implementation details |
| [TECHNOLOGY_DECISIONS.md](TECHNOLOGY_DECISIONS.md) | Technology stack decisions |
| [UX_DESIGN_GUIDE.md](UX_DESIGN_GUIDE.md) | UX design guidelines |
| [PRECOMMIT_HOOKS.md](PRECOMMIT_HOOKS.md) | Pre-commit hook setup |

## Development Principles

This codebase strictly follows:
- **Hexagonal Architecture** (Ports and Adapters)
- **SOLID Principles** (Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, Dependency Inversion)
- **Clean Architecture** with clear separation of concerns
- **MVVM Pattern** for presentation layer
- **Repository Pattern** for data access
- **DRY** (Don't Repeat Yourself)
- **KISS** (Keep It Simple, Stupid)
- **YAGNI** (You Aren't Gonna Need It)

All new code MUST adhere to these principles.

## Related Documentation

- [Architecture](../02-architecture/) - System architecture
- [Testing](../05-testing/) - Testing guides
- [API](../04-api/) - API documentation

---

[Back to Main Documentation](../README.md)
