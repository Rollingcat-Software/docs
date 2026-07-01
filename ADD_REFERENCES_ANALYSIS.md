# ADD.docx References - Deep Analysis

**Document:** ADD.docx (25.01.2026)
**Total References Listed:** 18
**Total Citations in Text:** 18 (all used)

---

## 1. CRITICAL ISSUES

### 1.1 Duplicate References

| Ref | Content | Duplicate Of | Action |
|-----|---------|--------------|--------|
| **[3]** | pgvector Extension | **[13]** pgvector Documentation | **MERGE** - Keep [3], remove [13] |
| **[7]** | Hexagonal Architecture (Cockburn) | **[15]** Hexagonal Architecture | **MERGE** - Keep [7], remove [15] |
| **[8]** | Docker Documentation | **[17]** Docker Compose Documentation | Keep both (different scope) |

**Impact:** References [13] and [15] are duplicates. Either merge or differentiate them.

---

### 1.2 Format Inconsistency

**References [1]-[12]** use proper academic format:
```
[4] Y. Taigman, M. Yang, M. Ranzato, and L. Wolf, "DeepFace: Closing
    the Gap to Human-Level Performance in Face Verification,"
    IEEE CVPR, 2014.
```

**References [13]-[18]** use informal format:
```
[13] pgvector Documentation - https://github.com/pgvector/pgvector
[14] FAISS Library - https://github.com/facebookresearch/faiss
[15] Hexagonal Architecture - Alistair Cockburn
```

**Fix Required:** Standardize [13]-[18] to match [1]-[12] format:
```
[13] PostgreSQL Global Development Group, pgvector Extension.
     Available: https://github.com/pgvector/pgvector
     Accessed: Jan. 2026.

[14] Facebook AI Research, FAISS: A Library for Efficient Similarity Search.
     Available: https://github.com/facebookresearch/faiss
     Accessed: Jan. 2026.

[15] A. Cockburn, "Hexagonal Architecture," Alistair Cockburn Blog.
     Available: https://alistair.cockburn.us/hexagonal-architecture/
     Accessed: Jan. 2026.

[16] Python Software Foundation, Python Documentation.
     Available: https://docs.python.org/
     Accessed: Jan. 2026.

[17] Docker Inc., Docker Compose Documentation.
     Available: https://docs.docker.com/compose/
     Accessed: Jan. 2026.

[18] C. Richardson, Microservices Patterns.
     O'Reilly Media, 2018.
```

---

## 2. MISSING CITATIONS (Should Add)

### 2.1 Face Recognition Models (Literature Survey - Section 2.2)

These models are mentioned but NOT cited:

| Model | Context | Suggested Reference |
|-------|---------|---------------------|
| **VGG-Face** | Table 2, Section 5.2.3 | O.M. Parkhi, A. Vedaldi, A. Zisserman, "Deep Face Recognition," BMVC, 2015 |
| **CosFace** | Section 2.2 | H. Wang et al., "CosFace: Large Margin Cosine Loss," CVPR, 2018 |
| **SphereFace** | Section 2.2 | W. Liu et al., "SphereFace: Deep Hypersphere Embedding," CVPR, 2017 |
| **MagFace** | Section 2.2 | Q. Meng et al., "MagFace: A Universal Representation," CVPR, 2021 |
| **AdaFace** | Section 2.2 | M. Kim et al., "AdaFace: Quality Adaptive Margin," CVPR, 2022 |
| **OpenFace** | Table 2 | B. Amos et al., "OpenFace: A general-purpose face recognition library," 2016 |
| **DeepID** | Table 2 | Y. Sun et al., "Deep Learning Face Representation," CVPR, 2014 |
| **Dlib** | Table 2 | D. King, "Dlib-ml: A Machine Learning Toolkit," JMLR, 2009 |
| **SFace** | Table 2, Section 5 | Y. Zhong et al., "SFace: Sigmoid-Constrained Hypersphere Loss," IEEE TIP, 2021 |

### 2.2 Face Detection Methods (Section 2.2, 6.1)

| Method | Context | Suggested Reference |
|--------|---------|---------------------|
| **MTCNN** | Section 6.1 | K. Zhang et al., "Joint Face Detection and Alignment using MTCNN," IEEE SPL, 2016 |
| **RetinaFace** | Section 6.1 | J. Deng et al., "RetinaFace: Single-shot Multi-level Face Localisation," CVPR, 2020 |

### 2.3 Other Technologies

| Technology | Context | Suggested Reference |
|------------|---------|---------------------|
| **DocFace** | Section 2.4 | Y. Shi, A.K. Jain, "DocFace: Matching ID Document Photos to Selfies," arXiv, 2018 |
| **ICAO 9303** | Section 2.4 | ICAO, "Machine Readable Travel Documents," Doc 9303, 2015 |
| **LBP** | Section 2.3, 6.1 | T. Ojala et al., "A comparative study of texture measures," PR, 1996 |
| **DeepFace Library** | Section 2.2 | S.I. Serengil, A. Ozpinar, "LightFace: A Hybrid Deep Face Recognition Framework," ASYU, 2020 |

---

## 3. REFERENCE USAGE ANALYSIS

### 3.1 Citation Frequency

| Ref | Times Cited | Used In Sections |
|-----|-------------|------------------|
| [1] | 2 | 1.1, References |
| [2] | 2 | 1.1, References |
| [3] | 2 | 1.2.1, References |
| [4] | 2 | 1.2.1, References |
| [5] | 2 | 1.2.1, References |
| [6] | 2 | 1.2.1, References |
| [7] | 2 | 1.2.2, References |
| [8] | 3 | 1.2.2, 1.2.3, References |
| [9] | 1 | References only |
| [10] | 1 | References only |
| [11] | 1 | References only |
| [12] | 1 | References only |
| [13] | 4 | 5.1, 5.3.1 |
| [14] | 1 | References only |
| [15] | 5 | 5.1, 5.2.1, 5.2.2, 5.2.3 |
| [16] | 2 | 5.4.1 |
| [17] | 3 | 5.4.1 |
| [18] | 4 | 5.1, 5.2.1 |

### 3.2 Underutilized References (Cited Only Once in References Section)

| Ref | Content | Issue |
|-----|---------|-------|
| **[9]** | ISO/IEC 30107-3 (Presentation Attack Detection) | **NOT CITED IN TEXT** - only appears in References |
| **[10]** | ArcFace paper | Only in References - should cite in Section 2.2 where ArcFace is discussed |
| **[11]** | FaceNet paper | Only in References - should cite in Section 2.2 where FaceNet is discussed |
| **[14]** | FAISS Library | Only in References - should cite in Section 2.6 where FAISS is mentioned |

---

## 4. SPECIFIC FIXES REQUIRED

### Fix 1: Add Citation for [9] in Text

**Location:** Section 2.3 (Liveness Detection)

**Current text:**
> "Face anti-spoofing techniques are commonly categorized into passive, active, and hybrid approaches."

**Add citation:**
> "Face anti-spoofing techniques are commonly categorized into passive, active, and hybrid approaches, as standardized in ISO/IEC 30107-3 [9]."

---

### Fix 2: Add Citations for [10] and [11] in Literature Survey

**Location:** Section 2.2, paragraph about ArcFace/FaceNet

**Current text:**
> "ArcFace introduced additive angular margin loss, achieving state-of-the-art performance on benchmarks such as LFW."

**Add citation:**
> "ArcFace [10] introduced additive angular margin loss, achieving state-of-the-art performance on benchmarks such as LFW."

**Current text:**
> "FaceNet further advanced the field by introducing a unified embedding space optimized using triplet loss"

**Add citation:**
> "FaceNet [11] further advanced the field by introducing a unified embedding space optimized using triplet loss"

---

### Fix 3: Add Citation for [14] in Text

**Location:** Section 2.6 (Cloud-Native Systems)

**Current text:**
> "Vector databases such as pgvector and similarity search libraries like FAISS enable efficient storage"

**Add citation:**
> "Vector databases such as pgvector [3] and similarity search libraries like FAISS [14] enable efficient storage"

---

### Fix 4: Remove Duplicate [13] or Merge with [3]

**Option A - Remove [13]:**
- Delete reference [13]
- Change all [13] citations to [3]
- Renumber [14]-[18] to [13]-[17]

**Option B - Differentiate:**
- [3] = pgvector academic/overview
- [13] = pgvector technical documentation

---

### Fix 5: Remove Duplicate [15] or Merge with [7]

**Option A - Remove [15]:**
- Delete reference [15]
- Change all [15] citations to [7]
- Renumber remaining references

**Option B - Keep both** (if [7] is the blog post and [15] is a book/paper)

---

### Fix 6: Standardize Reference Format

All references should follow this format:

**For Papers:**
```
[X] Author(s), "Title," Conference/Journal, Year.
```

**For Websites/Documentation:**
```
[X] Organization, Resource Title.
    Available: URL
    Accessed: Month Year.
```

**For Books:**
```
[X] Author(s), Title.
    Publisher, Year.
```

---

## 5. RECOMMENDED ADDITIONAL REFERENCES

To strengthen the Literature Survey, consider adding:

| Topic | Suggested Reference |
|-------|---------------------|
| Liveness Detection Survey | Z. Boulkenafet et al., "Face Anti-spoofing Based on Color Texture Analysis," ICIP, 2015 |
| Multi-tenant SaaS | B. Wilder, "Cloud Architecture Patterns," O'Reilly, 2012 |
| Biometric Template Protection | A.K. Jain et al., "Biometric Template Security," EURASIP, 2008 |
| GDPR & Biometrics | Article 9, GDPR (Special categories of personal data) |
| Turkish KVKK | Law No. 6698, Personal Data Protection Law |

---

## 6. SUMMARY CHECKLIST

### Must Fix (Before Submission)

- [ ] Add [9] citation in Section 2.3 (ISO/IEC 30107-3)
- [ ] Add [10] citation in Section 2.2 (ArcFace)
- [ ] Add [11] citation in Section 2.2 (FaceNet)
- [ ] Add [14] citation in Section 2.6 (FAISS)
- [ ] Resolve duplicate [3]/[13] (pgvector)
- [ ] Resolve duplicate [7]/[15] (Hexagonal Architecture)
- [ ] Standardize format of [13]-[18]

### Should Fix (Quality Improvement)

- [ ] Add VGG-Face citation in Table 2
- [ ] Add MTCNN citation in Section 6.1
- [ ] Add DeepFace library citation (Serengil & Ozpinar)
- [ ] Add LBP citation in Section 2.3

### Optional (Excellence)

- [ ] Add CosFace, SphereFace, MagFace, AdaFace citations
- [ ] Add ICAO 9303 citation
- [ ] Add DocFace citation

---

## 7. CORRECTED REFERENCE LIST (Proposed)

```
REFERENCES

[1] Verizon, 2024 Data Breach Investigations Report (DBIR).
    Available: https://www.verizon.com/business/resources/reports/dbir/
    Accessed: Jan. 2026.

[2] Identity Theft Resource Center, 2023 Data Breach Report.
    Available: https://www.idtheftcenter.org/
    Accessed: Jan. 2026.

[3] PostgreSQL Global Development Group, pgvector: Open-source Vector
    Similarity Search for Postgres.
    Available: https://github.com/pgvector/pgvector
    Accessed: Jan. 2026.

[4] Y. Taigman, M. Yang, M. Ranzato, and L. Wolf, "DeepFace: Closing
    the Gap to Human-Level Performance in Face Verification,"
    IEEE CVPR, 2014.

[5] Google, MediaPipe Face Landmark Detection.
    Available: https://developers.google.com/mediapipe/solutions/vision/face_landmarker
    Accessed: Jan. 2026.

[6] Redis Ltd., Redis Documentation.
    Available: https://redis.io/docs/
    Accessed: Jan. 2026.

[7] A. Cockburn, "Hexagonal Architecture," Alistair Cockburn Blog.
    Available: https://alistair.cockburn.us/hexagonal-architecture/
    Accessed: Jan. 2026.

[8] Docker Inc., Docker Documentation.
    Available: https://docs.docker.com/
    Accessed: Jan. 2026.

[9] ISO/IEC 30107-3:2017, Information Technology – Biometric Presentation
    Attack Detection – Part 3: Testing and Reporting.
    International Organization for Standardization, 2017.

[10] J. Deng, J. Guo, N. Xue, and S. Zafeiriou, "ArcFace: Additive Angular
     Margin Loss for Deep Face Recognition," IEEE/CVF CVPR, 2019.

[11] F. Schroff, D. Kalenichenko, and J. Philbin, "FaceNet: A Unified
     Embedding for Face Recognition and Clustering," IEEE CVPR, 2015.

[12] NGINX Inc., NGINX Official Documentation.
     Available: https://nginx.org/en/docs/
     Accessed: Jan. 2026.

[13] Facebook AI Research, FAISS: A Library for Efficient Similarity Search.
     Available: https://github.com/facebookresearch/faiss
     Accessed: Jan. 2026.

[14] Python Software Foundation, Python 3.11 Documentation.
     Available: https://docs.python.org/3.11/
     Accessed: Jan. 2026.

[15] Docker Inc., Docker Compose Documentation.
     Available: https://docs.docker.com/compose/
     Accessed: Jan. 2026.

[16] C. Richardson, Microservices Patterns: With Examples in Java.
     O'Reilly Media, 2018.

[17] S.I. Serengil and A. Ozpinar, "LightFace: A Hybrid Deep Face
     Recognition Framework," ASYU, 2020.

[18] O.M. Parkhi, A. Vedaldi, and A. Zisserman, "Deep Face Recognition,"
     British Machine Vision Conference (BMVC), 2015.
```

**Note:** This corrected list removes duplicates and adds missing academic citations.

---

**Created:** 2026-01-24
**Purpose:** Reference quality improvement for ADD.docx
