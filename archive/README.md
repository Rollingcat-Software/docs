# Documentation Archive

Historical docs preserved for git history. Content here is **not current** — see top-level `README.md` and the numbered module folders (`01-getting-started/` … `09-auth-flows/`) for authoritative docs.

## 2026-04-16

Bulk cleanup. Moved ~45 files out of the public docs tree because they were:

- **`ADD_*` drafts** — `ADD_CRITIQUE_REPORT`, `ADD_FIVUCSAS`, `ADD_FIX_PLAN`, `ADD_FIX_PROGRESS`, `ADD_CRITICAL_ANALYSIS_AND_RECOMMENDATIONS`, `ADD_GAP_ANALYSIS`, `ADD_REAL_ANALYSIS`, `ADD_LANDING_WEBSITE` — scratch "architecture design document" drafts, superseded by the numbered module folders.
- **`DOCS_MODULE_*` meta-docs** — 5 files about the docs system itself, kept in git history but no longer at the top of the navigation.
- **Dated status reports** — `FINAL_COMPLETION_REPORT`, `IMPLEMENTATION_STATUS_REPORT` (two copies), `KMP_IMPLEMENTATION_STATUS`, `MOBILE_APP_STATUS`, `MOBILE_APP_INVESTIGATION_2026`, `PROJECT_PROGRESS_PRESENTATION` — superseded by `ROADMAP.md`.
- **Duplicated PlantUML drafts** — `PLANTUML_DIAGRAMS_PART2` and the original pre-fix `PLANTUML_DIAGRAMS`; the `_FIXED` version was promoted to the canonical `PLANTUML_DIAGRAMS.md` name.
- **pgvector setup drafts** — 4 files (`PGVECTOR_SETUP`, `PGVECTOR_IMPLEMENTATION_CHECKLIST`, `QUICK_START_PGVECTOR`, `IMPLEMENTATION_SUMMARY_PGVECTOR`) superseded by production deployment.
- **Analysis / review drafts** — `API_CONTRACT_*`, `AUTH_METHOD_AUDIT`, `AUTH_TEST_VS_WEBAPP_ANALYSIS`, `BIOMETRIC_FLOW_RESEARCH`, `BACKEND_REVIEW`, `BACKEND_TEST_REPORT`, `CODE_ANALYSIS`, `IMPROVEMENT_RECOMMENDATIONS`, `MOBILE_APP_REFACTORING_PLAN`, `IDENTITY_CORE_API_ANALYSIS`, `SYSTEM_DESIGN_ANALYSIS_AND_DECISION`, `BACKEND_DAY_1_PLAN`, `BACKEND_NEXT_STEPS` — one-shot reviews, no longer action-bearing.
- **Presentation / prep** — `PRESENTATION_COMPLETE_GUIDE`, `PRESENTATION_SPEECHES`, `SCREENSHOTS_NEEDED`, `TASK_LOG_TEMPLATE`, `ANALYTICS_PLAN` (root; lives at `docs/plans/ANALYTICS_PLAN.md`).

All moves via `git mv` — authorship and timestamps preserved.
