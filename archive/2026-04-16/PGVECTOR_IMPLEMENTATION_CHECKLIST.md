# pgvector Implementation Checklist

Use this checklist to verify the pgvector implementation and deployment.

## Pre-Implementation Verification

- [x] PostgreSQL 16 with pgvector extension in docker-compose.yml
- [x] Database initialization scripts in place (`docs/sql/init/`)
- [x] Flyway migrations include biometric_data table (V4 migration)
- [x] IEmbeddingRepository interface defined in domain layer

## Code Implementation

### Biometric Processor (Python/FastAPI)

- [x] **Repository Implementation**
  - [x] File created: `pgvector_embedding_repository.py`
  - [x] Implements IEmbeddingRepository interface
  - [x] Uses asyncpg for async PostgreSQL operations
  - [x] Connection pooling implemented
  - [x] All methods implemented:
    - [x] `save()`
    - [x] `find_by_user_id()`
    - [x] `find_similar()`
    - [x] `delete()`
    - [x] `exists()`
    - [x] `count()`
    - [x] `health_check()`

- [x] **Configuration**
  - [x] `config.py` updated with database settings
  - [x] `DATABASE_URL` added
  - [x] `DATABASE_POOL_MIN_SIZE` added
  - [x] `DATABASE_POOL_MAX_SIZE` added
  - [x] `USE_PGVECTOR` toggle added
  - [x] `EMBEDDING_DIMENSION` added

- [x] **Dependency Injection**
  - [x] `container.py` updated
  - [x] Imports `PgVectorEmbeddingRepository`
  - [x] `get_embedding_repository()` supports both implementations
  - [x] Selection based on `USE_PGVECTOR` flag

- [x] **Dependencies**
  - [x] `requirements.txt` updated
  - [x] `asyncpg>=0.29.0` added
  - [x] `pgvector>=0.2.4` added

- [x] **Exports**
  - [x] `__init__.py` in repositories folder updated
  - [x] Exports `PgVectorEmbeddingRepository`

### Identity Core API (Java/Spring Boot)

- [x] **Database Migration**
  - [x] V4 migration updated for flexible vector dimensions
  - [x] `embedding vector` (no fixed dimension)
  - [x] `embedding_dimension INTEGER` column added
  - [x] Unique constraint added: `(user_id, tenant_id, biometric_type)`
  - [x] Comments updated for multi-model support

### Docker Configuration

- [x] **docker-compose.yml**
  - [x] PostgreSQL service uses `pgvector/pgvector:pg16` image
  - [x] Volume mount for init scripts: `./docs/sql/init:/docker-entrypoint-initdb.d`
  - [x] Biometric processor environment variables added:
    - [x] `DATABASE_URL`
    - [x] `DATABASE_POOL_MIN_SIZE`
    - [x] `DATABASE_POOL_MAX_SIZE`
    - [x] `USE_PGVECTOR`
    - [x] `EMBEDDING_DIMENSION`
  - [x] Biometric processor depends on PostgreSQL health check

### Database Initialization

- [x] **init.sql**
  - [x] Creates pgvector extension
  - [x] Creates uuid-ossp extension
  - [x] Sets timezone to UTC

- [x] **02_pgvector_setup.sql**
  - [x] Helper function: `check_embedding_similarity()`
  - [x] Helper function: `find_similar_faces()`
  - [x] View: `active_face_embeddings`
  - [x] View: `biometric_statistics`
  - [x] Additional indexes for query optimization

### Documentation

- [x] **PGVECTOR_SETUP.md**
  - [x] Architecture overview
  - [x] Configuration guide
  - [x] API examples
  - [x] Performance tuning
  - [x] Troubleshooting
  - [x] Security considerations
  - [x] Migration guide

- [x] **QUICK_START_PGVECTOR.md**
  - [x] Step-by-step enable instructions
  - [x] Model dimension table
  - [x] Verification steps
  - [x] Troubleshooting

- [x] **test_pgvector.sql**
  - [x] Extension verification
  - [x] Table structure check
  - [x] Index verification
  - [x] Performance testing
  - [x] Helper function tests

- [x] **IMPLEMENTATION_SUMMARY_PGVECTOR.md**
  - [x] Complete change summary
  - [x] Architecture diagrams
  - [x] Configuration modes
  - [x] Performance characteristics
  - [x] Migration paths

- [x] **.env.example**
  - [x] Database configuration section
  - [x] Notes about dimension matching
  - [x] Examples for different models

## Deployment Checklist

### Development Environment

- [ ] **Database Setup**
  - [ ] Start PostgreSQL: `docker-compose up -d postgres`
  - [ ] Verify pgvector extension: `docker-compose exec postgres psql -U postgres -d identity_core_db -c "SELECT * FROM pg_extension WHERE extname='vector';"`
  - [ ] Run test script: `docker-compose exec postgres psql -U postgres -d identity_core_db -f /docker-entrypoint-initdb.d/test_pgvector.sql`

- [ ] **Application Configuration**
  - [ ] Copy `.env.example` to `.env` in biometric-processor
  - [ ] Set `USE_PGVECTOR=False` (for initial testing with in-memory)
  - [ ] Set `EMBEDDING_DIMENSION` to match `FACE_RECOGNITION_MODEL`
  - [ ] Verify `DATABASE_URL` is correct

- [ ] **Service Startup**
  - [ ] Install Python dependencies: `pip install -r requirements.txt`
  - [ ] Start biometric-processor: `docker-compose up -d biometric-processor`
  - [ ] Check logs: `docker-compose logs biometric-processor | grep -i "embedding repository"`
  - [ ] Should see: "Creating embedding repository (in-memory)" or "(pgvector)"

- [ ] **Functional Testing**
  - [ ] Test health endpoint: `curl http://localhost:8001/health`
  - [ ] Test face enrollment (with in-memory): POST to `/api/v1/enroll`
  - [ ] Verify embedding stored (in-memory): Check logs

- [ ] **Enable pgvector**
  - [ ] Set `USE_PGVECTOR=True` in `.env` or `docker-compose.yml`
  - [ ] Restart service: `docker-compose restart biometric-processor`
  - [ ] Check logs: Should see "Creating embedding repository (pgvector)"
  - [ ] Test face enrollment (with pgvector): POST to `/api/v1/enroll`
  - [ ] Verify in database: `SELECT * FROM biometric_data WHERE user_id = 'test-user';`

### Production Environment

- [ ] **Security**
  - [ ] Change default PostgreSQL password
  - [ ] Use strong `DATABASE_URL` with production credentials
  - [ ] Enable SSL/TLS for database connections
  - [ ] Configure firewall rules for PostgreSQL port
  - [ ] Set up database user with minimal privileges
  - [ ] Enable PostgreSQL audit logging

- [ ] **Performance**
  - [ ] Set appropriate connection pool sizes (20-50 for high load)
  - [ ] Create vector indexes (IVFFlat or HNSW)
  - [ ] Run `ANALYZE biometric_data` after initial data load
  - [ ] Configure PostgreSQL shared_buffers (25% of RAM)
  - [ ] Set work_mem appropriately (4MB-16MB per connection)

- [ ] **Monitoring**
  - [ ] Set up health check endpoint monitoring
  - [ ] Monitor database connection pool metrics
  - [ ] Monitor query performance (p50, p95, p99)
  - [ ] Set up alerts for pool exhaustion
  - [ ] Monitor database storage usage
  - [ ] Track embedding count growth

- [ ] **Backup and Recovery**
  - [ ] Set up automated PostgreSQL backups (daily)
  - [ ] Test backup restoration procedure
  - [ ] Configure point-in-time recovery (PITR)
  - [ ] Document recovery procedures
  - [ ] Set up backup monitoring and alerts

- [ ] **High Availability**
  - [ ] Consider PostgreSQL replication (if needed)
  - [ ] Set up failover procedures
  - [ ] Test disaster recovery plan
  - [ ] Configure connection retry logic

## Testing Checklist

### Unit Tests

- [ ] Test `PgVectorEmbeddingRepository.save()`
- [ ] Test `PgVectorEmbeddingRepository.find_by_user_id()`
- [ ] Test `PgVectorEmbeddingRepository.find_similar()`
- [ ] Test `PgVectorEmbeddingRepository.delete()`
- [ ] Test `PgVectorEmbeddingRepository.exists()`
- [ ] Test `PgVectorEmbeddingRepository.count()`
- [ ] Test connection pool behavior
- [ ] Test error handling

### Integration Tests

- [ ] Test face enrollment flow (end-to-end)
- [ ] Test 1:1 face verification
- [ ] Test 1:N face identification
- [ ] Test multi-tenancy isolation
- [ ] Test concurrent requests
- [ ] Test connection pool under load
- [ ] Test database failover (if HA configured)

### Performance Tests

- [ ] Benchmark embedding save performance
- [ ] Benchmark 1:1 verification latency
- [ ] Benchmark 1:N search latency (1K, 10K, 100K embeddings)
- [ ] Measure index build time
- [ ] Test connection pool exhaustion handling
- [ ] Load test with concurrent users

### Manual Verification

- [ ] **Database**
  - [ ] Verify pgvector extension: `\dx`
  - [ ] Check table structure: `\d biometric_data`
  - [ ] Verify indexes: `\di+ biometric_data`
  - [ ] Check helper functions: `\df check_embedding_similarity`
  - [ ] Check views: `\dv`

- [ ] **Application**
  - [ ] Check logs for "pgvector" or "in-memory" message
  - [ ] Verify health check passes
  - [ ] Test API endpoints
  - [ ] Check metrics/monitoring

## Post-Deployment Checklist

- [ ] **Documentation Review**
  - [ ] Update deployment documentation
  - [ ] Document configuration decisions
  - [ ] Update runbooks
  - [ ] Create troubleshooting guide

- [ ] **Training**
  - [ ] Train team on pgvector configuration
  - [ ] Review monitoring dashboards
  - [ ] Practice recovery procedures
  - [ ] Document common issues and solutions

- [ ] **Optimization**
  - [ ] Review query performance after 1 week
  - [ ] Adjust connection pool if needed
  - [ ] Rebuild indexes if necessary
  - [ ] Tune PostgreSQL configuration

## Rollback Plan

If issues occur, follow these steps:

1. **Disable pgvector**
   - [ ] Set `USE_PGVECTOR=False`
   - [ ] Restart biometric-processor
   - [ ] Verify in-memory mode working

2. **Investigate Issue**
   - [ ] Check application logs
   - [ ] Check database logs
   - [ ] Review configuration
   - [ ] Check network connectivity

3. **Fix and Re-enable**
   - [ ] Address root cause
   - [ ] Set `USE_PGVECTOR=True`
   - [ ] Test thoroughly
   - [ ] Monitor closely

## Sign-off

- [ ] Development Team Lead
- [ ] Database Administrator
- [ ] DevOps/Infrastructure Team
- [ ] QA Team
- [ ] Product Owner

---

**Date**: _______________

**Approved By**: _______________

**Notes**:
```
[Add any deployment-specific notes or special considerations here]
```
