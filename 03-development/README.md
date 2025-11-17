# Development Documentation

Guides for developers working on the FIVUCSAS platform.

## Essential Reading

**⭐ START HERE:** [CLAUDE.md](CLAUDE.md) - Main developer guide with:
- Project overview and current status
- Architecture principles (SOLID, Clean Architecture, DRY, KISS, YAGNI)
- Repository structure
- Development workflow for each component
- Common development tasks
- Key design patterns used
- Critical conventions
- Troubleshooting guides

## Implementation Guides

- **[KOTLIN_MULTIPLATFORM_GUIDE.md](KOTLIN_MULTIPLATFORM_GUIDE.md)** - Mobile/desktop app development (1,061 lines)
- **[FLUTTER_APP_GUIDE.md](FLUTTER_APP_GUIDE.md)** - Flutter app (if applicable)
- **[COMPLETE_IMPLEMENTATION_GUIDE.md](COMPLETE_IMPLEMENTATION_GUIDE.md)** - Complete implementation details
- **[IMPLEMENTATION_ROADMAP.md](IMPLEMENTATION_ROADMAP.md)** - Implementation roadmap
- **[IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md)** - Implementation guide

## Code Quality

- **[CODE_REVIEW_ACTION_GUIDE.md](CODE_REVIEW_ACTION_GUIDE.md)** - Code review process
- **[CODE_REVIEW_AND_REFACTORING.md](CODE_REVIEW_AND_REFACTORING.md)** - Code review and refactoring
- **[REFACTORING_CHECKLIST.md](REFACTORING_CHECKLIST.md)** - Refactoring checklist
- **[REFACTORING_SUMMARY.md](REFACTORING_SUMMARY.md)** - Refactoring summary
- **[CODE_ANALYSIS_AND_FIXES.md](CODE_ANALYSIS_AND_FIXES.md)** - Code analysis
- **[COMPLETE_CODE_ANALYSIS_AND_FIXES.md](COMPLETE_CODE_ANALYSIS_AND_FIXES.md)** - Complete code analysis

## Design & Planning

- **[MOBILE_APP_REFACTORING_PLAN.md](MOBILE_APP_REFACTORING_PLAN.md)** - Mobile app refactoring plan
- **[UI_OPTIMIZATION_PLAN.md](UI_OPTIMIZATION_PLAN.md)** - UI optimization plan
- **[IMPROVEMENT_RECOMMENDATIONS.md](IMPROVEMENT_RECOMMENDATIONS.md)** - Improvement recommendations
- **[TECHNOLOGY_DECISIONS.md](TECHNOLOGY_DECISIONS.md)** - Technology stack decisions

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

[← Back to Main Documentation](../README.md)
