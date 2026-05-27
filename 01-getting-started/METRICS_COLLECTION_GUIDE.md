# Metrics Collection Guide for ADD Section 6.1

**TEAM ACTION REQUIRED:** Run these benchmarks and collect actual performance metrics.

---

## Critical Requirement

**CSE4197 ADD Guide states:**
> "you also should present your preliminary experimental results about the tasks accomplished so far"

Your ADD currently shows completion percentages but **no actual performance data**.

---

## Required Metrics

### A. Biometric Accuracy Metrics

#### A1: Face Recognition Accuracy

**What to measure:**
- Model comparison across different embeddings
- False Acceptance Rate (FAR)
- False Rejection Rate (FRR)
- Equal Error Rate (EER)

**How to collect:**

```bash
cd biometric-processor

# If you have a test script:
python tests/benchmark/face_recognition_accuracy.py

# Manual test approach:
# 1. Create test dataset: 10 known faces, 5 unknown faces
# 2. Enroll 10 known faces
# 3. Test verification:
#    - Verify each known face (should match) → calculate FRR
#    - Test unknown faces (should reject) → calculate FAR
```

**Expected results to document:**

| Model | Embedding Dim | Accuracy | FAR | FRR | Threshold |
|-------|--------------|----------|-----|-----|-----------|
| Facenet | 128 | [X%] | [X%] | [X%] | [X] |
| Facenet512 | 512 | [X%] | [X%] | [X%] | [X] |
| ArcFace | 512 | [X%] | [X%] | [X%] | [X] |
| VGG-Face | 2622 | [X%] | [X%] | [X%] | [X] |

#### A2: Liveness Detection Accuracy

**What to measure:**
- True Positive Rate (legitimate users passing)
- True Negative Rate (spoof attacks detected)
- Challenge completion time

**How to collect:**

```bash
# Test with legitimate users
# 1. Have 5-10 people complete biometric puzzle
# 2. Record: Pass rate, average time, failure reasons

# Test with spoofing attempts
# 1. Try photo attacks (print, screen)
# 2. Try video replay attacks
# 3. Record: Detection rate
```

**Expected results:**

| Attack Type | Attempts | Detected | Detection Rate | Avg Time (s) |
|-------------|----------|----------|----------------|--------------|
| Legitimate Users | [N] | [Pass] | [X%] | [X] |
| Photo (Print) | [N] | [Blocked] | [X%] | - |
| Photo (Screen) | [N] | [Blocked] | [X%] | - |
| Video Replay | [N] | [Blocked] | [X%] | - |

---

### B. Performance Benchmarks

#### B1: API Response Time

**What to measure:**
- Average response time for key endpoints
- 95th percentile latency
- Throughput (requests/second)

**How to collect:**

```bash
cd biometric-processor

# Option 1: Use Apache Bench
ab -n 1000 -c 10 http://localhost:8001/api/v1/health

# Option 2: Use Python script
python tests/benchmark/api_performance.py

# Option 3: Check application logs for timing
# FastAPI automatically logs request duration
```

**Endpoints to benchmark:**

| Endpoint | Avg Response (ms) | p95 (ms) | p99 (ms) | Throughput (RPS) |
|----------|-------------------|----------|----------|------------------|
| POST /api/v1/enroll | [X] | [X] | [X] | [X] |
| POST /api/v1/verify | [X] | [X] | [X] | [X] |
| POST /api/v1/search | [X] | [X] | [X] | [X] |
| POST /api/v1/liveness | [X] | [X] | [X] | [X] |
| POST /auth/login (Identity Core) | [X] | [X] | [X] | [X] |

#### B2: Face Processing Latency

**What to measure:**
- Face detection time
- Embedding generation time
- Vector search time

**How to collect:**

```python
# Add timing to your biometric processor
import time

start = time.time()
# Face detection
detection_time = time.time() - start

start = time.time()
# Embedding generation
embedding_time = time.time() - start

start = time.time()
# Vector search (pgvector)
search_time = time.time() - start
```

**Expected results:**

| Operation | Sample Size | Avg Time (ms) | Min (ms) | Max (ms) | Hardware |
|-----------|-------------|---------------|----------|----------|----------|
| Face Detection | 100 images | [X] | [X] | [X] | CPU: [spec] |
| Embedding (Facenet) | 100 faces | [X] | [X] | [X] | CPU: [spec] |
| Embedding (ArcFace) | 100 faces | [X] | [X] | [X] | CPU: [spec] |
| Vector Search (1K) | 100 queries | [X] | [X] | [X] | PostgreSQL 16 |
| Vector Search (10K) | 100 queries | [X] | [X] | [X] | PostgreSQL 16 |

#### B3: Vector Database Performance

**What to measure:**
- Query time vs database size
- Index build time
- Memory usage

**How to collect:**

```sql
-- In PostgreSQL, measure query performance
EXPLAIN ANALYZE
SELECT user_id, 1 - (embedding <=> '[0.1, 0.2, ...]'::vector) AS similarity
FROM biometric_data
WHERE tenant_id = '...'
ORDER BY embedding <=> '[0.1, 0.2, ...]'::vector
LIMIT 10;

-- Check index size
SELECT pg_size_pretty(pg_relation_size('biometric_data_embedding_idx'));

-- Benchmark at different scales
-- Insert 1K, 10K, 50K, 100K embeddings and measure search time
```

**Expected results:**

| DB Size | Index Size | Query Time (ms) | Build Time (s) |
|---------|------------|-----------------|----------------|
| 1,000 embeddings | [X MB] | [X] | [X] |
| 10,000 embeddings | [X MB] | [X] | [X] |
| 50,000 embeddings | [X MB] | [X] | [X] |
| 100,000 embeddings | [X MB] | [X] | [X] |

---

### C. Code Quality Metrics

#### C1: Test Coverage

**How to collect:**

```bash
# For Identity Core (Java/Spring Boot)
cd identity-core-api
./gradlew test jacocoTestReport
# Report generated at: build/reports/jacoco/test/html/index.html

# For Biometric Processor (Python/FastAPI)
cd biometric-processor
pytest --cov=app --cov-report=html --cov-report=term
# Report generated at: htmlcov/index.html
```

**Expected results:**

| Component | Lines Covered | Total Lines | Coverage % | Branch Coverage % |
|-----------|---------------|-------------|------------|-------------------|
| Identity Core API | [X] | [X] | [X%] | [X%] |
| Biometric Processor | [X] | [X] | [X%] | [X%] |
| Client Apps (KMP) | [X] | [X] | [X%] | [X%] |
| Overall | [X] | [X] | [X%] | [X%] |

#### C2: Code Metrics

**How to collect:**

```bash
# Lines of Code
find . -name "*.java" | xargs wc -l
find . -name "*.py" | xargs wc -l
find . -name "*.kt" | xargs wc -l

# Or use cloc tool
cloc identity-core-api/src/main/java
cloc biometric-processor/app
cloc client-apps/shared
```

**Expected results:**

| Component | Files | Lines of Code | Comments | Blank Lines | Total |
|-----------|-------|---------------|----------|-------------|-------|
| Identity Core (Java) | [X] | [X] | [X] | [X] | [X] |
| Biometric Processor (Python) | [X] | [X] | [X] | [X] | [X] |
| Demo UI (TypeScript) | [X] | [X] | [X] | [X] | [X] |
| Mobile/Desktop (Kotlin) | [X] | [X] | [X] | [X] | [X] |
| **Total** | [X] | [X] | [X] | [X] | [X] |

#### C3: Cyclomatic Complexity

**How to collect:**

```bash
# Java (using SonarQube or PMD)
# Or manually count from IDE metrics

# Python (using radon)
pip install radon
radon cc biometric-processor/app -a

# Results: A=low, B=medium, C=high, D=very high complexity
```

---

### D. System Resource Usage

**What to measure:**
- Memory consumption
- CPU usage under load
- Docker container sizes

**How to collect:**

```bash
# Monitor during load test
docker stats

# Or use Python profiling
python -m memory_profiler app/main.py
```

**Expected results:**

| Component | Idle Memory | Peak Memory | CPU (idle) | CPU (load) | Container Size |
|-----------|-------------|-------------|------------|------------|----------------|
| Identity Core API | [X MB] | [X MB] | [X%] | [X%] | [X MB] |
| Biometric Processor | [X MB] | [X MB] | [X%] | [X%] | [X MB] |
| PostgreSQL | [X MB] | [X MB] | [X%] | [X%] | [X MB] |
| Redis | [X MB] | [X MB] | [X%] | [X%] | [X MB] |

---

## Integration into ADD Document

Once metrics are collected, add to **Section 6.1: Current State of the System**

### Suggested Structure:

```markdown
## 6.1 Current State of the System

### 6.1.1 Implementation Progress
[Existing progress tables]

### 6.1.2 Preliminary Experimental Results

#### 6.1.2.1 Biometric Accuracy Results

**Face Recognition Performance:**
[Table with model comparison]

**Observations:**
- ArcFace model achieved highest accuracy (X%) with threshold 0.X
- VGG-Face provides best discrimination but slower inference (X ms)
- Facenet offers best balance of speed and accuracy for production use

**Liveness Detection Results:**
[Table with attack detection rates]

**Observations:**
- Biometric Puzzle achieved X% detection rate against photo attacks
- Average completion time for legitimate users: X seconds
- Zero false positives in test set of N users

#### 6.1.2.2 Performance Benchmarks

**API Response Times:**
[Table with endpoint latencies]

**Observations:**
- All authentication endpoints meet NFR-1.1 target (<200ms at p95)
- Face search performance scales linearly up to 50K enrollments
- pgvector IVFFlat index provides 10x speedup vs sequential scan

**Vector Database Scalability:**
[Table with DB size vs query time]

**Observations:**
- Query time remains under 100ms for up to 100K vectors (meets NFR-1.4)
- Index build time: ~X seconds per 10K embeddings
- Memory usage: ~X MB per 10K embeddings

#### 6.1.2.3 Code Quality Metrics

**Test Coverage:**
[Table with coverage percentages]

**Observations:**
- Identity Core: X% coverage (target: >70%, status: [PASS/FAIL])
- Biometric Processor: X% coverage
- Critical paths (authentication, enrollment) achieve >90% coverage

**Codebase Statistics:**
[Table with LOC counts]

**Cyclomatic Complexity:**
- Average complexity: X (rating: [A/B/C])
- No functions exceed complexity threshold of 10
```

---

## Quick Start for Minimal Metrics

If time is limited, collect at minimum:

1. **One model accuracy test** (e.g., Facenet with 10 test faces)
2. **API response time** for `/enroll` and `/verify` (run 100 requests each)
3. **Test coverage** percentage (run existing test suite)
4. **Lines of code** count (use `cloc` or `wc -l`)

**Time required:** ~1 hour

---

## Tools You Can Use

- **Apache Bench:** `sudo apt-get install apache2-utils`
- **cloc:** `sudo apt-get install cloc`
- **radon (Python):** `pip install radon`
- **pytest-cov:** `pip install pytest-cov`
- **JaCoCo (Java):** Already in Gradle config

---

## Notes

- **Hardware specs:** Document CPU, RAM for reproducibility
- **Test conditions:** Specify load (concurrent users, request rate)
- **Datasets:** Mention if using public datasets (LFW, CASIA) or custom
- **Disclaimer:** Can note "preliminary results" if not production-scale

---

**Guide Created:** January 20, 2026
**Purpose:** Fulfill CSE4197 ADD Section 6.1 experimental results requirement
**Priority:** HIGH - Adds significant credibility to ADD
**Estimated effort:** 2-3 hours for comprehensive metrics
