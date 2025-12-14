# PostgreSQL with pgvector Setup Guide

## Overview

This guide explains how to set up and use PostgreSQL with the pgvector extension for efficient face embedding storage and similarity search in the FIVUCSAS system.

## Architecture

The system uses PostgreSQL with pgvector for production-grade face embedding storage:

- **Database**: PostgreSQL 16 with pgvector extension
- **Embedding Storage**: `biometric_data` table with vector column
- **Similarity Search**: Cosine distance using pgvector operators
- **Indexing**: HNSW or IVFFlat for approximate nearest neighbor search
- **Multi-Tenancy**: Tenant isolation via `tenant_id` column

## Components Modified

### 1. Biometric Processor (Python/FastAPI)

#### New Repository Implementation
- **File**: `biometric-processor/app/infrastructure/persistence/repositories/pgvector_embedding_repository.py`
- **Purpose**: Production-ready PostgreSQL repository with pgvector support
- **Features**:
  - Async operations using asyncpg
  - Connection pooling (configurable size)
  - Vector similarity search (cosine distance)
  - Multi-tenancy support
  - UPSERT logic for embeddings

#### Configuration Updates
- **File**: `biometric-processor/app/core/config.py`
- **New Settings**:
  - `DATABASE_URL`: PostgreSQL connection string
  - `DATABASE_POOL_MIN_SIZE`: Minimum connections (default: 10)
  - `DATABASE_POOL_MAX_SIZE`: Maximum connections (default: 20)
  - `USE_PGVECTOR`: Toggle between pgvector and in-memory (default: False)
  - `EMBEDDING_DIMENSION`: Vector dimension (FaceNet: 512, VGG-Face: 2622)

#### Dependency Injection
- **File**: `biometric-processor/app/core/container.py`
- **Update**: `get_embedding_repository()` now returns either:
  - `PgVectorEmbeddingRepository` if `USE_PGVECTOR=True`
  - `InMemoryEmbeddingRepository` if `USE_PGVECTOR=False`

#### Dependencies
- **File**: `biometric-processor/requirements.txt`
- **Added**:
  - `asyncpg>=0.29.0` - PostgreSQL async driver
  - `pgvector>=0.2.4` - Python client for pgvector

### 2. Identity Core API (Java/Spring Boot)

#### Database Migration
- **File**: `identity-core-api/src/main/resources/db/migration/V4__create_biometric_tables.sql`
- **Updates**:
  - Changed `embedding vector(2622)` to `embedding vector` (flexible dimension)
  - Added `embedding_dimension INTEGER` column to track vector size
  - Added unique constraint on `(user_id, tenant_id, biometric_type)`
  - Updated comments to reflect multi-model support

### 3. Docker Compose

#### PostgreSQL Service
- **Image**: `pgvector/pgvector:pg16`
- **Volume Mount**: `./docs/sql/init:/docker-entrypoint-initdb.d`
- **Auto-initialization**: Runs all `.sql` files in init directory on first start

#### Biometric Processor Service
- **New Environment Variables**:
  ```yaml
  DATABASE_URL: postgresql://postgres:postgres_dev_password@postgres:5432/identity_core_db
  DATABASE_POOL_MIN_SIZE: 10
  DATABASE_POOL_MAX_SIZE: 20
  USE_PGVECTOR: "False"  # Set to "True" to enable
  EMBEDDING_DIMENSION: 512
  ```
- **Dependencies**: Now depends on PostgreSQL service health check

### 4. Database Initialization Scripts

#### init.sql
- **File**: `docs/sql/init/init.sql`
- **Purpose**: Basic database setup
- **Actions**:
  - Creates pgvector extension
  - Creates uuid-ossp extension
  - Sets timezone to UTC

#### 02_pgvector_setup.sql
- **File**: `docs/sql/init/02_pgvector_setup.sql` (NEW)
- **Purpose**: pgvector-specific setup and utilities
- **Features**:
  - Helper function: `check_embedding_similarity()` - Compare two user embeddings
  - Helper function: `find_similar_faces()` - Test 1:N identification
  - View: `active_face_embeddings` - Convenient access to active embeddings
  - View: `biometric_statistics` - Monitoring statistics by tenant/model
  - Additional indexes for common query patterns

## Usage

### Development Mode (In-Memory Repository)

By default, the system uses in-memory storage for development:

```bash
# In docker-compose.yml or .env
USE_PGVECTOR=False
```

Features:
- Fast startup
- No database dependency
- Data lost on restart
- Suitable for testing and development

### Production Mode (pgvector Repository)

Enable PostgreSQL storage for production:

```bash
# In docker-compose.yml or .env
USE_PGVECTOR=True
DATABASE_URL=postgresql://postgres:password@postgres:5432/identity_core_db
EMBEDDING_DIMENSION=512  # Match your face recognition model
```

Features:
- Persistent storage
- Scalable to millions of faces
- Sub-second similarity search with indexes
- Multi-tenant support
- ACID compliance

## Face Recognition Models Support

The system supports multiple face recognition models with different embedding dimensions:

| Model | Dimension | Configuration |
|-------|-----------|---------------|
| FaceNet | 512 | `EMBEDDING_DIMENSION=512` |
| Facenet512 | 512 | `EMBEDDING_DIMENSION=512` |
| VGG-Face | 2622 | `EMBEDDING_DIMENSION=2622` |
| ArcFace | 512 | `EMBEDDING_DIMENSION=512` |
| OpenFace | 128 | `EMBEDDING_DIMENSION=128` |

**Important**: The `EMBEDDING_DIMENSION` must match your chosen `FACE_RECOGNITION_MODEL`.

## Vector Similarity Search

### Distance Metrics

pgvector supports multiple distance metrics. This implementation uses **cosine distance**:

- **Operator**: `<=>`
- **Range**: 0.0 (identical) to 1.0 (opposite)
- **Formula**: `1 - cosine_similarity`
- **Best for**: Face embeddings (normalized vectors)

### Indexing Strategies

Two index types are available for approximate nearest neighbor search:

#### 1. IVFFlat (Default in V4 migration)
```sql
CREATE INDEX idx_biometric_embedding_ivfflat
    ON biometric_data
    USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100);
```

**Characteristics**:
- Faster index build time
- Lower memory usage
- Good recall with proper `lists` parameter
- Recommended for: 100K - 1M embeddings

**Tuning**:
- `lists`: Typically `sqrt(total_rows)` to `4 * sqrt(total_rows)`
- More lists = faster search, slower build

#### 2. HNSW (Alternative, commented in migration)
```sql
CREATE INDEX idx_biometric_embedding_hnsw
    ON biometric_data
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);
```

**Characteristics**:
- Better recall than IVFFlat
- Higher memory usage
- More consistent performance
- Recommended for: High-accuracy requirements

**Tuning**:
- `m`: Higher = better recall, more memory (default: 16)
- `ef_construction`: Higher = better index quality, slower build (default: 64)

### Query Performance

Expected query performance (approximate):

| Records | IVFFlat | HNSW | Notes |
|---------|---------|------|-------|
| 10K | <10ms | <5ms | Linear scan still fast |
| 100K | 10-50ms | 5-20ms | Indexes recommended |
| 1M | 50-200ms | 20-100ms | Indexes required |
| 10M+ | 100-500ms | 50-200ms | Consider partitioning |

## API Examples

### Save Embedding

```python
from app.core.container import get_embedding_repository
import numpy as np

repository = get_embedding_repository()

# Save face embedding
await repository.save(
    user_id="550e8400-e29b-41d4-a716-446655440000",
    embedding=np.random.rand(512),  # Your face embedding
    quality_score=85.5,
    tenant_id="123e4567-e89b-12d3-a456-426614174000"
)
```

### Find by User ID (1:1 Verification)

```python
# Retrieve user's embedding
embedding = await repository.find_by_user_id(
    user_id="550e8400-e29b-41d4-a716-446655440000",
    tenant_id="123e4567-e89b-12d3-a456-426614174000"
)

if embedding is not None:
    # Compare with new image embedding
    distance = calculate_cosine_distance(embedding, new_embedding)
    is_match = distance < 0.6  # Threshold
```

### Find Similar (1:N Identification)

```python
# Search for similar faces
matches = await repository.find_similar(
    embedding=query_embedding,
    threshold=0.6,  # Maximum cosine distance
    limit=5,  # Top 5 matches
    tenant_id="123e4567-e89b-12d3-a456-426614174000"
)

for user_id, distance in matches:
    similarity = 1.0 - distance
    print(f"User: {user_id}, Similarity: {similarity:.2%}")
```

### Delete Embedding

```python
# Soft delete (sets deleted_at timestamp)
deleted = await repository.delete(
    user_id="550e8400-e29b-41d4-a716-446655440000",
    tenant_id="123e4567-e89b-12d3-a456-426614174000"
)
```

## Database Utilities

### Check Embedding Similarity (SQL)

```sql
-- Compare two users' face embeddings
SELECT * FROM check_embedding_similarity(
    '550e8400-e29b-41d4-a716-446655440000'::UUID,  -- user1
    '6ba7b810-9dad-11d1-80b4-00c04fd430c8'::UUID,  -- user2
    '123e4567-e89b-12d3-a456-426614174000'::UUID   -- tenant (optional)
);
```

### Find Similar Faces (SQL)

```sql
-- Search for similar embeddings
SELECT * FROM find_similar_faces(
    '[0.1, 0.2, ..., 0.5]'::vector,  -- query embedding
    0.6,  -- threshold
    5,    -- limit
    '123e4567-e89b-12d3-a456-426614174000'::UUID  -- tenant (optional)
);
```

### View Statistics

```sql
-- Check biometric data statistics by tenant
SELECT * FROM biometric_statistics;

-- Count total active embeddings
SELECT COUNT(*) FROM active_face_embeddings;

-- Average quality by model
SELECT
    embedding_model,
    AVG(quality_score) as avg_quality,
    COUNT(*) as total
FROM active_face_embeddings
GROUP BY embedding_model;
```

## Migration Guide

### From In-Memory to pgvector

1. **Update configuration**:
   ```bash
   USE_PGVECTOR=True
   EMBEDDING_DIMENSION=512  # Match your model
   ```

2. **Restart services**:
   ```bash
   docker-compose down
   docker-compose up -d
   ```

3. **Verify connection**:
   ```bash
   docker-compose logs biometric-processor | grep "pgvector"
   # Should see: "Creating embedding repository (pgvector)"
   ```

4. **Re-enroll faces**: Existing in-memory data is lost; users must re-enroll.

### Between Face Recognition Models

If changing models (e.g., VGG-Face → FaceNet):

1. **Update configuration**:
   ```bash
   FACE_RECOGNITION_MODEL=Facenet512
   EMBEDDING_DIMENSION=512  # Must match model
   ```

2. **Migration strategy** (choose one):
   - **Option A**: Soft delete old embeddings, re-enroll all users
   - **Option B**: Keep both models temporarily, migrate gradually
   - **Option C**: Extract new embeddings from stored images (if available)

3. **Update database** (if needed):
   ```sql
   -- Mark old embeddings as inactive
   UPDATE biometric_data
   SET is_active = FALSE
   WHERE embedding_model = 'VGG-Face';
   ```

## Performance Tuning

### Connection Pooling

Adjust based on your workload:

```bash
# For high concurrency (many simultaneous users)
DATABASE_POOL_MIN_SIZE=20
DATABASE_POOL_MAX_SIZE=50

# For low concurrency (fewer users, save resources)
DATABASE_POOL_MIN_SIZE=5
DATABASE_POOL_MAX_SIZE=10
```

### Index Optimization

Monitor and rebuild indexes periodically:

```sql
-- Check index usage
SELECT schemaname, tablename, indexname, idx_scan
FROM pg_stat_user_indexes
WHERE tablename = 'biometric_data';

-- Rebuild index if needed (after bulk inserts)
REINDEX INDEX CONCURRENTLY idx_biometric_embedding_ivfflat;
```

### Query Optimization

```sql
-- Analyze table for query planner
ANALYZE biometric_data;

-- Check query plan
EXPLAIN ANALYZE
SELECT user_id, embedding <=> '[...]'::vector AS distance
FROM biometric_data
WHERE tenant_id = '...'
  AND is_active = TRUE
  AND deleted_at IS NULL
ORDER BY distance
LIMIT 5;
```

## Monitoring

### Health Check

```python
repository = get_embedding_repository()
is_healthy = await repository.health_check()
```

### Metrics to Monitor

1. **Embedding count**: `SELECT COUNT(*) FROM active_face_embeddings`
2. **Query latency**: Monitor p50, p95, p99 search times
3. **Connection pool**: Watch for pool exhaustion
4. **Index usage**: Ensure vector index is being used
5. **Storage size**: `SELECT pg_size_pretty(pg_total_relation_size('biometric_data'))`

## Troubleshooting

### "pgvector extension not found"

```bash
# Ensure using pgvector-enabled PostgreSQL image
docker-compose down
docker-compose pull postgres
docker-compose up -d postgres
```

### "Embedding dimension mismatch"

- Ensure `EMBEDDING_DIMENSION` matches your `FACE_RECOGNITION_MODEL`
- Check application logs for actual embedding size
- Verify database column can store the dimension

### Slow similarity search

1. Check if index exists:
   ```sql
   SELECT indexname FROM pg_indexes
   WHERE tablename = 'biometric_data' AND indexname LIKE '%embedding%';
   ```

2. Ensure index is being used:
   ```sql
   EXPLAIN SELECT ... FROM biometric_data WHERE embedding <=> ...
   -- Should show "Index Scan using idx_biometric_embedding_..."
   ```

3. Rebuild index if needed:
   ```sql
   REINDEX INDEX CONCURRENTLY idx_biometric_embedding_ivfflat;
   ```

### Connection pool exhausted

- Increase `DATABASE_POOL_MAX_SIZE`
- Check for connection leaks (unclosed connections)
- Monitor concurrent requests

## Security Considerations

1. **Encryption at rest**: Consider PostgreSQL TDE for sensitive biometric data
2. **Access control**: Use separate database users with minimal permissions
3. **Audit logging**: Enable PostgreSQL audit log for compliance
4. **Network security**: Use SSL/TLS for database connections in production
5. **Backup**: Regular backups of biometric_data table

## References

- [pgvector Documentation](https://github.com/pgvector/pgvector)
- [asyncpg Documentation](https://magicstack.github.io/asyncpg/)
- [PostgreSQL Performance Tuning](https://wiki.postgresql.org/wiki/Performance_Optimization)
- [Vector Similarity Search Best Practices](https://github.com/pgvector/pgvector#performance)
