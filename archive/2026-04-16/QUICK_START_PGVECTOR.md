# Quick Start: Enable pgvector for Face Embeddings

This guide shows you how to enable PostgreSQL with pgvector for persistent face embedding storage in FIVUCSAS.

## Prerequisites

- Docker and Docker Compose installed
- FIVUCSAS project cloned
- Basic understanding of environment variables

## Steps

### 1. Enable pgvector in Biometric Processor

Edit `docker-compose.yml` and set:

```yaml
biometric-processor:
  environment:
    USE_PGVECTOR: "True"  # Change from "False" to "True"
    EMBEDDING_DIMENSION: 512  # Match your FACE_MODEL
```

Or create/edit `biometric-processor/.env`:

```bash
USE_PGVECTOR=True
EMBEDDING_DIMENSION=512
DATABASE_URL=postgresql://postgres:postgres_dev_password@postgres:5432/identity_core_db
```

### 2. Match Embedding Dimension to Face Model

| Face Model | Embedding Dimension | Configuration |
|------------|---------------------|---------------|
| Facenet512 | 512 | `FACE_MODEL=Facenet512`<br>`EMBEDDING_DIMENSION=512` |
| VGG-Face | 2622 | `FACE_MODEL=VGG-Face`<br>`EMBEDDING_DIMENSION=2622` |
| ArcFace | 512 | `FACE_MODEL=ArcFace`<br>`EMBEDDING_DIMENSION=512` |
| OpenFace | 128 | `FACE_MODEL=OpenFace`<br>`EMBEDDING_DIMENSION=128` |

**Example for FaceNet (Recommended)**:

```yaml
FACE_MODEL: Facenet512
EMBEDDING_DIMENSION: 512
USE_PGVECTOR: "True"
```

### 3. Restart Services

```bash
# Stop all services
docker-compose down

# Start services (database will auto-initialize)
docker-compose up -d

# Check logs
docker-compose logs biometric-processor | grep -i pgvector
# Should see: "Creating embedding repository (pgvector)"
```

### 4. Verify Setup

Check if pgvector is working:

```bash
# Connect to database
docker-compose exec postgres psql -U postgres -d identity_core_db

# Verify pgvector extension
\dx
# Should show "vector" extension

# Check biometric_data table
\d biometric_data
# Should show "embedding" column of type "vector"

# Exit
\q
```

### 5. Test Face Enrollment

Enroll a face via API:

```bash
curl -X POST http://localhost:8001/api/v1/enroll \
  -F "user_id=test-user-123" \
  -F "tenant_id=test-tenant" \
  -F "image=@/path/to/face.jpg"
```

Verify in database:

```bash
docker-compose exec postgres psql -U postgres -d identity_core_db -c \
  "SELECT user_id, embedding_model, embedding_dimension, quality_score FROM biometric_data WHERE user_id = 'test-user-123';"
```

## Switching from In-Memory to pgvector

### What Happens

- **Before**: Face embeddings stored in RAM, lost on restart
- **After**: Face embeddings stored in PostgreSQL, persistent across restarts

### Important Notes

1. **Data Migration**: Existing in-memory embeddings are NOT automatically migrated
   - Users must re-enroll their faces after enabling pgvector

2. **Database Initialization**:
   - First startup creates necessary tables and indexes
   - This is handled automatically by Flyway migrations

3. **Performance**:
   - In-memory: Faster (no network/disk overhead)
   - pgvector: Slightly slower but scales to millions of faces

## Configuration Options

### Connection Pool Tuning

For high-concurrency systems:

```yaml
DATABASE_POOL_MIN_SIZE: 20
DATABASE_POOL_MAX_SIZE: 50
```

For low-concurrency systems (save resources):

```yaml
DATABASE_POOL_MIN_SIZE: 5
DATABASE_POOL_MAX_SIZE: 10
```

### Production Configuration

```yaml
# Production settings
ENVIRONMENT: production
USE_PGVECTOR: "True"
DATABASE_URL: postgresql://biometric_user:STRONG_PASSWORD@db.example.com:5432/fivucsas_prod
DATABASE_POOL_MIN_SIZE: 20
DATABASE_POOL_MAX_SIZE: 50

# Use FaceNet for production (good balance of accuracy and speed)
FACE_MODEL: Facenet512
EMBEDDING_DIMENSION: 512
SIMILARITY_THRESHOLD: 0.4
```

## Troubleshooting

### "pgvector extension not found"

**Symptom**: Error during startup about missing pgvector

**Solution**:
```bash
docker-compose down
docker-compose pull postgres  # Pull latest pgvector/pgvector:pg16 image
docker-compose up -d
```

### "Embedding dimension mismatch"

**Symptom**: Error like "expected 512, got 2622"

**Cause**: `EMBEDDING_DIMENSION` doesn't match `FACE_MODEL`

**Solution**: Check the table above and ensure they match

### "Connection refused" or "Pool exhausted"

**Symptom**: Cannot connect to database or pool is full

**Solutions**:
1. Check if PostgreSQL is running: `docker-compose ps postgres`
2. Increase pool size: `DATABASE_POOL_MAX_SIZE=50`
3. Check database logs: `docker-compose logs postgres`

### Slow similarity search

**Symptom**: Face search takes >1 second

**Solutions**:

1. Check if vector index exists:
   ```sql
   SELECT indexname FROM pg_indexes
   WHERE tablename = 'biometric_data' AND indexname LIKE '%embedding%';
   ```

2. If missing, create index:
   ```sql
   CREATE INDEX idx_biometric_embedding_ivfflat
   ON biometric_data
   USING ivfflat (embedding vector_cosine_ops)
   WITH (lists = 100)
   WHERE deleted_at IS NULL AND is_active = TRUE;
   ```

3. Analyze table:
   ```sql
   ANALYZE biometric_data;
   ```

## Monitoring

### Check Embedding Count

```bash
docker-compose exec postgres psql -U postgres -d identity_core_db -c \
  "SELECT COUNT(*) FROM biometric_data WHERE is_active = TRUE AND deleted_at IS NULL;"
```

### Check Average Quality

```bash
docker-compose exec postgres psql -U postgres -d identity_core_db -c \
  "SELECT embedding_model, AVG(quality_score) as avg_quality, COUNT(*) as total FROM biometric_data WHERE is_active = TRUE GROUP BY embedding_model;"
```

### View Statistics

```bash
docker-compose exec postgres psql -U postgres -d identity_core_db -c \
  "SELECT * FROM biometric_statistics;"
```

## Rollback to In-Memory

If you need to revert to in-memory storage:

1. Edit `docker-compose.yml`:
   ```yaml
   USE_PGVECTOR: "False"
   ```

2. Restart:
   ```bash
   docker-compose restart biometric-processor
   ```

**Note**: Database data remains intact; you can switch back anytime.

## Next Steps

- Read full documentation: `docs/PGVECTOR_SETUP.md`
- Configure face recognition model: `docs/FACE_RECOGNITION_MODELS.md`
- Production deployment guide: `docs/PRODUCTION_DEPLOYMENT.md`
- Performance tuning: `docs/PERFORMANCE_TUNING.md`

## Support

For issues or questions:
1. Check application logs: `docker-compose logs biometric-processor`
2. Check database logs: `docker-compose logs postgres`
3. Review full documentation: `docs/PGVECTOR_SETUP.md`
