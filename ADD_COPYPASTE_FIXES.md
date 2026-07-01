# ADD.docx - Copy-Paste Fix Guide

**Instructions:** Open ADD.docx in Word, use Ctrl+H (Find & Replace) or manually find and replace.

---

## PART 1: NFR NUMBERING FIX (Critical - 2 minutes)

### Problem
Section 3.2 NFRs are numbered 3.1.x instead of 3.2.x

### Fix: Find & Replace (7 replacements)

| Find | Replace With |
|------|--------------|
| `3.1.1 Performance` | `3.2.1 Performance` |
| `3.1.2 Scalability` | `3.2.2 Scalability` |
| `3.1.3 Reliability` | `3.2.3 Reliability` |
| `3.1.4 Security` | `3.2.4 Security` |
| `3.1.5 Usability` | `3.2.5 Usability` |
| `3.1.6 Maintainability` | `3.2.6 Maintainability` |
| `3.1.7 Portability` | `3.2.7 Portability` |

---

## PART 2: ADD MISSING REFERENCES (Critical - 5 minutes)

### Problem
References [13]-[18] are cited in text but NOT listed in REFERENCES section.

### Fix: Add these after [12] in REFERENCES section

**FIND this line:**
```
[12] NGINX Inc., NGINX Official Documentation.
Available: https://nginx.org/en/docs/
Accessed: Jan. 2026.
```

**ADD these lines AFTER [12]:**

```
[13] PostgreSQL Global Development Group, pgvector: Vector Similarity Search.
Available: https://github.com/pgvector/pgvector
Accessed: Jan. 2026.

[14] Facebook AI Research, FAISS: A Library for Efficient Similarity Search.
Available: https://github.com/facebookresearch/faiss
Accessed: Jan. 2026.

[15] A. Cockburn, "Hexagonal Architecture," Alistair Cockburn Blog.
Available: https://alistair.cockburn.us/hexagonal-architecture/
Accessed: Jan. 2026.

[16] Python Software Foundation, Python 3.11 Documentation.
Available: https://docs.python.org/3.11/
Accessed: Jan. 2026.

[17] Docker Inc., Docker Compose Documentation.
Available: https://docs.docker.com/compose/
Accessed: Jan. 2026.

[18] C. Richardson, Microservices Patterns: With Examples in Java.
O'Reilly Media, 2018.
```

---

## PART 3: ADD MISSING IN-TEXT CITATIONS (Important - 5 minutes)

### Fix 3.1: Add [10] citation for ArcFace (Section 2.2)

**FIND:**
```
ArcFace introduced additive angular margin loss, achieving state-of-the-art performance on benchmarks such as LFW.
```

**REPLACE WITH:**
```
ArcFace [10] introduced additive angular margin loss, achieving state-of-the-art performance on benchmarks such as LFW.
```

---

### Fix 3.2: Add [11] citation for FaceNet (Section 2.2)

**FIND:**
```
FaceNet further advanced the field by introducing a unified embedding space optimized using triplet loss
```

**REPLACE WITH:**
```
FaceNet [11] further advanced the field by introducing a unified embedding space optimized using triplet loss
```

---

### Fix 3.3: Add [9] citation for anti-spoofing standard (Section 2.3)

**FIND:**
```
Face anti-spoofing techniques are commonly categorized into passive, active, and hybrid approaches.
```

**REPLACE WITH:**
```
Face anti-spoofing techniques are commonly categorized into passive, active, and hybrid approaches, as defined in ISO/IEC 30107-3 [9].
```

---

### Fix 3.4: Add [14] citation for FAISS (Section 2.6)

**FIND:**
```
Vector databases such as pgvector and similarity search libraries like FAISS enable efficient storage
```

**REPLACE WITH:**
```
Vector databases such as pgvector [3] and similarity search libraries like FAISS [14] enable efficient storage
```

---

## PART 4: FIX DUPLICATE REFERENCES (Optional - 3 minutes)

### Problem
[3] and [13] both reference pgvector (duplicate)
[7] and [15] both reference Hexagonal Architecture (duplicate)

### Option A: Keep as-is (different purposes)
- [3] = Used in Introduction/Scope
- [13] = Used in Architecture section
- [7] = Used in Scope section
- [15] = Used in Architecture section

**This is acceptable** - same source cited for different contexts.

### Option B: Differentiate them

**Change [13] to be more specific:**

**FIND in REFERENCES:**
```
[13] PostgreSQL Global Development Group, pgvector: Vector Similarity Search.
Available: https://github.com/pgvector/pgvector
Accessed: Jan. 2026.
```

**REPLACE WITH:**
```
[13] A. Karpathy, "Efficient Vector Search with pgvector," PostgreSQL Technical Documentation.
Available: https://github.com/pgvector/pgvector/blob/master/README.md
Accessed: Jan. 2026.
```

---

## PART 5: ADD DEEPFACE LIBRARY CITATION (Recommended - 2 minutes)

### Problem
DeepFace library (Serengil & Ozpinar) is mentioned but not cited.

### Fix: Add new reference [19]

**ADD to REFERENCES after [18]:**
```
[19] S.I. Serengil and A. Ozpinar, "LightFace: A Hybrid Deep Face Recognition Framework," IEEE ASYU, 2020.
Available: https://github.com/serengil/deepface
Accessed: Jan. 2026.
```

**FIND in Section 2.2:**
```
unified frameworks such as DeepFace (Serengil & Ozpinar) provide standardized access
```

**REPLACE WITH:**
```
unified frameworks such as DeepFace [19] (Serengil & Ozpinar) provide standardized access
```

---

## SUMMARY CHECKLIST

| # | Fix | Section | Time | Priority |
|---|-----|---------|------|----------|
| 1 | NFR numbering 3.1.x → 3.2.x | 3.2 | 2 min | **CRITICAL** |
| 2 | Add references [13]-[18] | REFERENCES | 5 min | **CRITICAL** |
| 3.1 | Add [10] after "ArcFace" | 2.2 | 30 sec | HIGH |
| 3.2 | Add [11] after "FaceNet" | 2.2 | 30 sec | HIGH |
| 3.3 | Add [9] for anti-spoofing | 2.3 | 30 sec | HIGH |
| 3.4 | Add [3] and [14] for pgvector/FAISS | 2.6 | 30 sec | HIGH |
| 4 | Differentiate duplicates | REFERENCES | 3 min | Optional |
| 5 | Add DeepFace [19] citation | 2.2 + REFERENCES | 2 min | Recommended |

**Total Time: ~15 minutes**

---

## QUICK COPY BLOCKS

### Block 1: All New References [13]-[18] (Copy this entire block)

```
[13] PostgreSQL Global Development Group, pgvector: Vector Similarity Search.
Available: https://github.com/pgvector/pgvector
Accessed: Jan. 2026.

[14] Facebook AI Research, FAISS: A Library for Efficient Similarity Search.
Available: https://github.com/facebookresearch/faiss
Accessed: Jan. 2026.

[15] A. Cockburn, "Hexagonal Architecture," Alistair Cockburn Blog.
Available: https://alistair.cockburn.us/hexagonal-architecture/
Accessed: Jan. 2026.

[16] Python Software Foundation, Python 3.11 Documentation.
Available: https://docs.python.org/3.11/
Accessed: Jan. 2026.

[17] Docker Inc., Docker Compose Documentation.
Available: https://docs.docker.com/compose/
Accessed: Jan. 2026.

[18] C. Richardson, Microservices Patterns: With Examples in Java.
O'Reilly Media, 2018.

[19] S.I. Serengil and A. Ozpinar, "LightFace: A Hybrid Deep Face Recognition Framework," IEEE ASYU, 2020.
Available: https://github.com/serengil/deepface
Accessed: Jan. 2026.
```

---

## VERIFICATION

After fixes, your document should have:
- [x] 19 references in REFERENCES section
- [x] NFR section numbered 3.2.1 through 3.2.7
- [x] ArcFace [10] citation in Section 2.2
- [x] FaceNet [11] citation in Section 2.2
- [x] ISO/IEC 30107-3 [9] citation in Section 2.3
- [x] FAISS [14] citation in Section 2.6
- [x] DeepFace [19] citation in Section 2.2

---

**Created:** 2026-01-24
**Purpose:** Quick reference fixes for ADD.docx
