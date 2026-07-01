# ADD.docx Defect Checklist

**Document:** ADD.docx (25.01.2026)
**Reviewed Against:** CSE4197 ADD Guidelines
**Current Grade Estimate:** 7.0-7.5/10
**After Fixes:** 8.5-9.0/10

---

## What We Have (Good)

| Section | Status | Notes |
|---------|--------|-------|
| 1. Introduction | ✅ Complete | Problem, Scope, Definitions all present |
| 2. Literature Survey | ✅ Excellent | Comprehensive 7-section review |
| 4.1 Use Case Diagrams | ✅ Complete | 3 diagrams with descriptions |
| 4.1.4 Sequence Diagrams | ✅ Complete | Registration, Enrollment, Search flows |
| 4.2 Class/ER Diagrams | ✅ Complete | Domain model + 2 ER diagrams |
| 4.4 Test Plan | ✅ Complete | Strategy + test cases + timeline |
| 5. Software Architecture | ✅ Excellent | Hexagonal architecture, components, data layer |
| 6.2 Task Log | ✅ Has 11 meetings | Sept 2025 - Jan 2026 documented |
| 6.3 Gantt Chart | ✅ Complete | Fall + Spring semester tables |
| 7. References | ✅ Mostly complete | 12 references listed |

---

## What to Change (Defects)

### CRITICAL - Must Fix

| # | Section | Problem | Fix Required | Time |
|---|---------|---------|--------------|------|
| 1 | **3.2 NFRs** | Numbered as 3.1.x instead of 3.2.x | Change 3.1.1→3.2.1, 3.1.2→3.2.2, etc. | 15 min |
| 2 | **6.1 Results** | No experimental metrics | Add FAR/FRR, latency, test coverage numbers | 2-3 hrs |
| 3 | **4.3 UI** | Verify screenshots exist | If missing, add 5-6 screenshots | 30 min |

### HIGH - Should Fix

| # | Section | Problem | Fix Required | Time |
|---|---------|---------|--------------|------|
| 4 | **6.2 Task Log** | Missing Location, Duration, Attendees | Add to each of 11 meetings | 1 hr |
| 5 | **3.2 NFRs** | No measurable values | Add specific numbers (e.g., "99.5% uptime") | 1 hr |
| 6 | **References** | [13]-[18] cited but not listed | Add missing 6 references | 30 min |

### MEDIUM - Consider Fixing

| # | Section | Problem | Fix Required | Time |
|---|---------|---------|--------------|------|
| 7 | **3.1 FRs** | Paragraph format instead of hierarchical | Restructure to 3.1.1.1-3.1.1.5 format | 3-4 hrs |

---

## Detailed Fix Instructions

### Fix #1: NFR Section Numbering (15 min)

**Find and replace:**
```
3.1.1 Performance    →  3.2.1 Performance
3.1.2 Scalability    →  3.2.2 Scalability
3.1.3 Reliability    →  3.2.3 Reliability
3.1.4 Security       →  3.2.4 Security
3.1.5 Usability      →  3.2.5 Usability
3.1.6 Maintainability→  3.2.6 Maintainability
3.1.7 Portability    →  3.2.7 Portability
```

---

### Fix #2: Add Preliminary Results to Section 6.1 (2-3 hrs)

**Add after the current 6.1 text:**

```markdown
6.1.2 Preliminary Experimental Results

Biometric Accuracy Metrics:
| Metric | Value | Test Dataset |
|--------|-------|--------------|
| Face Detection Rate | XX% | LFW subset (100 images) |
| False Acceptance Rate (FAR) | X.XX% | Internal test set |
| False Rejection Rate (FRR) | X.XX% | Internal test set |
| Liveness Detection Accuracy | XX% | 50 spoof attempts |

Performance Benchmarks:
| Operation | Avg Latency | Hardware |
|-----------|-------------|----------|
| Face Detection | XXX ms | Intel i7, 16GB RAM |
| Embedding Generation | XXX ms | CPU inference |
| 1:N Search (1000 faces) | XXX ms | pgvector IVFFlat |
| API Response (auth) | XXX ms | Docker environment |

Test Coverage:
| Component | Coverage | Test Cases |
|-----------|----------|------------|
| Identity Core API | XX% | XXX tests |
| Biometric Processor | XX% | XXX tests |
```

**How to collect:** Run `pytest --cov` and API benchmarks.

---

### Fix #3: Verify UI Screenshots (30 min)

**Check if ADD.docx contains actual images in Section 4.3.**

If missing, add screenshots of:
1. Login page
2. Dashboard
3. Face enrollment (with camera)
4. Liveness challenge
5. Verification result

---

### Fix #4: Complete Task Log Format (1 hr)

**Current format:**
```
Meeting 1 – 12.09.2025
Final Engineering Project topic was selected...
```

**Required format:**
```
Meeting 1
Date: 12.09.2025
Location: Faculty of Engineering, Office 302
Duration: 60 minutes
Attendees: AAG, AGE, AA, Dr. Mustafa Ağaoğlu
Objectives:
- Select project topic
- Assign team roles
Decisions:
- FIVUCSAS approved as project topic
- Roles assigned: AAG-Backend, AGE-Mobile, AA-Biometrics
```

---

### Fix #5: Add Measurable NFR Values (1 hr)

**Update each NFR with specific metrics:**

| NFR | Add This |
|-----|----------|
| Performance | "Authentication < 500ms, Verification < 1s" |
| Scalability | "Support 100 tenants, 10,000 users/tenant" |
| Reliability | "99.5% availability, RTO < 15 min, MTTR < 1 hr" |
| Security | "BCrypt work factor 12, JWT expiry 15 min" |
| Usability | "Enrollment success rate > 95% on first attempt" |

---

### Fix #6: Add Missing References (30 min)

**Add references [13]-[18] that are cited in Section 5:**

```
[13] pgvector Documentation - https://github.com/pgvector/pgvector
[14] FAISS Library - https://github.com/facebookresearch/faiss
[15] Hexagonal Architecture - Alistair Cockburn
[16] Python Official Documentation - https://docs.python.org/
[17] Docker Compose Documentation - https://docs.docker.com/compose/
[18] Microservices Patterns - Chris Richardson
```

---

## Quick Reference: CSE4197 Requirements

### Section 6.2 Task Log Format (Mandatory):
```
Meeting#1:
  Date:
  Location:
  Period:
  Attendees:
  Objectives:
  Decisions and Notes:
```

### Section 3.1 FR Format (Mandatory):
```
3.1.1 Functional Requirement #1
  3.1.1.1 Description
  3.1.1.2 Inputs
  3.1.1.3 Processing
  3.1.1.4 Outputs
  3.1.1.5 Error/Data Handling
```

### Section 6.1 Must Include:
> "preliminary experimental results about the tasks accomplished"

### Section 4.3 Must Include:
> "sample screen-shots of your project's Graphical User Interfaces"

---

## Total Estimated Fix Time

| Priority | Items | Time |
|----------|-------|------|
| Critical | #1, #2, #3 | 3-4 hours |
| High | #4, #5, #6 | 2.5 hours |
| Medium | #7 | 3-4 hours (optional) |
| **Total (without #7)** | | **5.5-6.5 hours** |

---

**Created:** 2026-01-24
**Purpose:** Guide for ADD.docx corrections before submission
