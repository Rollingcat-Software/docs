# ADD.docx Reference Fixes - Final Copy-Paste Guide

## Current State Analysis

**References in REFERENCES section:** [1] through [16]
**Citations used in text:** [1] through [18]
**MISSING from references:** [17], [18]

### Critical Mismatches Found

| Citation in Text | Context | Current Ref | Should Be |
|------------------|---------|-------------|-----------|
| [13] | "pgvector extension [13]" (Section 5.3.1) | FAISS | pgvector (use [3]) OR add new |
| [15] | "Hexagonal Architecture [15]" (Section 5.2) | Docker Compose | Hexagonal (use [7]) |
| [17] | "Docker network [17]" | **MISSING** | Need to add |
| [18] | "microservices [18]" | **MISSING** | Need to add |

---

## OPTION A: QUICK FIX (Fix Citation Numbers in Text)

This is faster - change the citation numbers in text to match existing references.

### Fix A1: Change [13] to [3] for pgvector

**FIND (Section 5.3.1):**
```
Database: PostgreSQL 16 with pgvector extension [13]
```

**REPLACE WITH:**
```
Database: PostgreSQL 16 with pgvector extension [3]
```

**FIND (Section 5.3.1):**
```
Vector Storage: pgvector with IVFFlat indexing for similarity search [13]
```

**REPLACE WITH:**
```
Vector Storage: pgvector with IVFFlat indexing for similarity search [3]
```

---

### Fix A2: Change [15] to [7] for Hexagonal Architecture

**FIND (Section 5.1):**
```
Scalability: Services scale independently based on load [15]
```

**REPLACE WITH:**
```
Scalability: Services scale independently based on load [7]
```

**FIND (Section 5.1):**
```
independent of frameworks, databases, and communication mechanisms. [15]
```

**REPLACE WITH:**
```
independent of frameworks, databases, and communication mechanisms. [7]
```

**FIND (Section 5.2.2):**
```
supports multi-tenant scalability and security requirements. [15]
```

**REPLACE WITH:**
```
supports multi-tenant scalability and security requirements. [7]
```

**FIND (Section 5.2.3):**
```
without affecting higher-level services. [15]
```

**REPLACE WITH:**
```
without affecting higher-level services. [7]
```

---

### Fix A3: Change [16][17][18] to match existing refs

**FIND (Section 5.4.1):**
```
development environment. [16][17][18]
```

**REPLACE WITH:**
```
development environment. [8][14][16]
```

*Explanation: [8]=Docker, [14]=Python, [16]=Microservices Patterns*

---

### Fix A4: Change [17] to [8] for Docker

**FIND (Section 5.4.1):**
```
within a unified Docker network. [17]
```

**REPLACE WITH:**
```
within a unified Docker network. [8]
```

---

### Fix A5: Change [13][18] in intro

**FIND (Section 5 intro):**
```
across the entire platform.[13][18]
```

**REPLACE WITH:**
```
across the entire platform. [7][16]
```

*Explanation: [7]=Hexagonal Architecture, [16]=Microservices Patterns*

---

### Fix A6: Change [18] for ML integration

**FIND (Section 5.2.1):**
```
machine learning integration. [18]
```

**REPLACE WITH:**
```
machine learning integration. [16]
```

---

## OPTION B: ADD MISSING REFERENCES (More Complete)

Keep all citation numbers as-is in text, add missing [17] and [18] to REFERENCES.

### Fix B1: Add [17] and [18] to REFERENCES

**FIND the end of references (after [16]):**
```
[16] C. Richardson, Microservices Patterns.
     O'Reilly Media, 2018.
```

**ADD AFTER [16]:**
```
[17] Docker Inc., Docker Networking Documentation.
Available: https://docs.docker.com/network/
Accessed: Jan. 2026.

[18] S. Newman, Building Microservices: Designing Fine-Grained Systems.
O'Reilly Media, 2nd Edition, 2021.
```

---

### Fix B2: Still need to fix [13] and [15] mismatches

Even with Option B, [13] and [15] in text don't match references:
- [13] in text = pgvector context, but [13] in refs = FAISS
- [15] in text = Hexagonal context, but [15] in refs = Docker Compose

**Either:**
1. Change [13] → [3] in text (pgvector)
2. Change [15] → [7] in text (Hexagonal)

**OR reorder references [13]-[16] to match text usage.**

---

## RECOMMENDED: OPTION A + Additional Citations

### Complete Fix List (Do All of These)

| Step | Find | Replace | Section |
|------|------|---------|---------|
| 1 | `[13]` (pgvector context) | `[3]` | 5.3.1 (2 places) |
| 2 | `[15]` (Hexagonal context) | `[7]` | 5.1, 5.2.2, 5.2.3 (4 places) |
| 3 | `[17]` (Docker context) | `[8]` | 5.4.1 |
| 4 | `[13][18]` | `[7][16]` | 5 intro |
| 5 | `[16][17][18]` | `[8][14][16]` | 5.4.1 |
| 6 | `[18]` (ML context) | `[16]` | 5.2.1 |

**After these fixes, delete [17] and [18] from text (they won't exist).**

---

## ALSO ADD: Missing In-Text Citations

### Add [10] for ArcFace (Section 2.2)

**FIND:**
```
ArcFace introduced additive angular margin loss
```

**REPLACE WITH:**
```
ArcFace [10] introduced additive angular margin loss
```

---

### Add [11] for FaceNet (Section 2.2)

**FIND:**
```
FaceNet further advanced the field
```

**REPLACE WITH:**
```
FaceNet [11] further advanced the field
```

---

### Add [9] for ISO standard (Section 2.3)

**FIND:**
```
Face anti-spoofing techniques are commonly categorized into passive, active, and hybrid approaches.
```

**REPLACE WITH:**
```
Face anti-spoofing techniques are commonly categorized into passive, active, and hybrid approaches, as standardized in ISO/IEC 30107-3 [9].
```

---

## NFR NUMBERING FIX (Still Required!)

**Find & Replace these 7 items:**

| Find | Replace |
|------|---------|
| `3.1.1 Performance` | `3.2.1 Performance` |
| `3.1.2 Scalability` | `3.2.2 Scalability` |
| `3.1.3 Reliability` | `3.2.3 Reliability` |
| `3.1.4 Security` | `3.2.4 Security` |
| `3.1.5 Usability` | `3.2.5 Usability` |
| `3.1.6 Maintainability` | `3.2.6 Maintainability` |
| `3.1.7 Portability` | `3.2.7 Portability` |

---

## FINAL CHECKLIST

After all fixes:

- [ ] NFR section numbered 3.2.1 - 3.2.7 ✓
- [ ] No [17] or [18] citations in text (changed to existing refs)
- [ ] All [13] for pgvector changed to [3]
- [ ] All [15] for Hexagonal changed to [7]
- [ ] ArcFace has [10] citation
- [ ] FaceNet has [11] citation
- [ ] ISO/IEC 30107-3 has [9] citation
- [ ] References section has [1]-[16] (no gaps)

---

## SUMMARY: Minimum Required Fixes

| Priority | Action | Time |
|----------|--------|------|
| **CRITICAL** | Fix NFR numbering (3.1.x → 3.2.x) | 2 min |
| **CRITICAL** | Change [13]→[3], [15]→[7], [17]→[8], [18]→[16] in text | 5 min |
| **HIGH** | Add [10] for ArcFace, [11] for FaceNet | 1 min |
| **HIGH** | Add [9] for ISO standard | 1 min |

**Total: ~10 minutes**

---

**Created:** 2026-01-24
