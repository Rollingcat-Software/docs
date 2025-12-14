-- FIVUCSAS pgvector Test Script
-- Use this script to verify pgvector setup and test functionality

\echo '=================================='
\echo 'FIVUCSAS pgvector Verification'
\echo '=================================='
\echo ''

-- 1. Check pgvector extension
\echo '1. Checking pgvector extension...'
SELECT
    extname AS "Extension Name",
    extversion AS "Version"
FROM pg_extension
WHERE extname = 'vector';

\echo ''
\echo '2. Checking biometric_data table structure...'
\d biometric_data

\echo ''
\echo '3. Checking vector indexes...'
SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'biometric_data'
  AND indexname LIKE '%embedding%';

\echo ''
\echo '4. Checking active embeddings count...'
SELECT
    'Total Active Embeddings' AS metric,
    COUNT(*) AS value
FROM biometric_data
WHERE biometric_type = 'FACE'
  AND is_active = TRUE
  AND deleted_at IS NULL;

\echo ''
\echo '5. Checking embeddings by model...'
SELECT
    embedding_model AS "Model",
    embedding_dimension AS "Dimension",
    COUNT(*) AS "Count",
    AVG(quality_score)::NUMERIC(5,2) AS "Avg Quality",
    COUNT(*) FILTER (WHERE liveness_verified = TRUE) AS "Liveness Verified"
FROM biometric_data
WHERE biometric_type = 'FACE'
  AND is_active = TRUE
  AND deleted_at IS NULL
GROUP BY embedding_model, embedding_dimension
ORDER BY embedding_model;

\echo ''
\echo '6. Checking database size...'
SELECT
    pg_size_pretty(pg_database_size(current_database())) AS "Database Size",
    pg_size_pretty(pg_total_relation_size('biometric_data')) AS "biometric_data Size",
    pg_size_pretty(pg_relation_size('biometric_data')) AS "Table Size",
    pg_size_pretty(pg_total_relation_size('biometric_data') - pg_relation_size('biometric_data')) AS "Indexes Size";

\echo ''
\echo '7. Testing vector similarity functions...'
\echo 'Creating test embeddings...'

-- Create temporary test data
DO $$
DECLARE
    test_tenant_id UUID := '00000000-0000-0000-0000-000000000000';
    test_user1_id UUID := '11111111-1111-1111-1111-111111111111';
    test_user2_id UUID := '22222222-2222-2222-2222-222222222222';
    test_embedding1 vector;
    test_embedding2 vector;
BEGIN
    -- Check if test tenant exists, if not skip test data creation
    IF NOT EXISTS (SELECT 1 FROM tenants WHERE id = test_tenant_id) THEN
        RAISE NOTICE 'Test tenant not found. Skipping test data creation.';
        RETURN;
    END IF;

    -- Check if test users exist
    IF NOT EXISTS (SELECT 1 FROM users WHERE id = test_user1_id) THEN
        RAISE NOTICE 'Test user1 not found. Skipping test data creation.';
        RETURN;
    END IF;

    -- Generate random 512-dimensional embeddings for testing
    SELECT array_to_string(
        ARRAY(SELECT random() FROM generate_series(1, 512)),
        ','
    )::vector INTO test_embedding1;

    SELECT array_to_string(
        ARRAY(SELECT random() FROM generate_series(1, 512)),
        ','
    )::vector INTO test_embedding2;

    -- Insert or update test embeddings
    INSERT INTO biometric_data (
        user_id,
        tenant_id,
        embedding,
        embedding_model,
        embedding_dimension,
        quality_score,
        biometric_type,
        is_active
    ) VALUES
    (test_user1_id, test_tenant_id, test_embedding1, 'Facenet512', 512, 0.85, 'FACE', TRUE),
    (test_user2_id, test_tenant_id, test_embedding2, 'Facenet512', 512, 0.90, 'FACE', TRUE)
    ON CONFLICT (user_id, tenant_id, biometric_type) WHERE deleted_at IS NULL
    DO UPDATE SET
        embedding = EXCLUDED.embedding,
        quality_score = EXCLUDED.quality_score,
        updated_at = CURRENT_TIMESTAMP;

    RAISE NOTICE 'Test embeddings created successfully';
END $$;

\echo ''
\echo '8. Testing cosine distance calculation...'
SELECT
    b1.user_id AS user1,
    b2.user_id AS user2,
    b1.embedding <=> b2.embedding AS cosine_distance,
    1.0 - (b1.embedding <=> b2.embedding) AS cosine_similarity
FROM biometric_data b1
CROSS JOIN biometric_data b2
WHERE b1.user_id = '11111111-1111-1111-1111-111111111111'
  AND b2.user_id = '22222222-2222-2222-2222-222222222222'
  AND b1.is_active = TRUE
  AND b2.is_active = TRUE
  AND b1.deleted_at IS NULL
  AND b2.deleted_at IS NULL
LIMIT 1;

\echo ''
\echo '9. Testing similarity search performance...'
\echo 'Searching for top 5 similar faces...'

EXPLAIN ANALYZE
SELECT
    user_id,
    embedding <=> (
        SELECT embedding
        FROM biometric_data
        WHERE user_id = '11111111-1111-1111-1111-111111111111'
          AND is_active = TRUE
          AND deleted_at IS NULL
        LIMIT 1
    ) AS distance
FROM biometric_data
WHERE is_active = TRUE
  AND deleted_at IS NULL
  AND biometric_type = 'FACE'
ORDER BY distance
LIMIT 5;

\echo ''
\echo '10. Checking helper functions...'
SELECT
    proname AS "Function Name",
    pronargs AS "Argument Count",
    prosrc AS "Source"
FROM pg_proc
WHERE proname IN ('check_embedding_similarity', 'find_similar_faces')
ORDER BY proname;

\echo ''
\echo '11. Checking views...'
SELECT
    viewname AS "View Name",
    definition AS "Definition"
FROM pg_views
WHERE viewname IN ('active_face_embeddings', 'biometric_statistics')
ORDER BY viewname;

\echo ''
\echo '=================================='
\echo 'Verification Complete!'
\echo '=================================='
\echo ''
\echo 'Summary:'
\echo '- If you see pgvector extension: ✓ Extension is installed'
\echo '- If you see vector indexes: ✓ Indexes are created for performance'
\echo '- If you see embeddings: ✓ System is storing face embeddings'
\echo '- If EXPLAIN shows "Index Scan": ✓ Queries are optimized'
\echo ''
\echo 'Next steps:'
\echo '1. Enable USE_PGVECTOR=True in biometric-processor'
\echo '2. Restart services: docker-compose restart biometric-processor'
\echo '3. Test face enrollment via API'
\echo '4. Monitor performance and adjust pool settings as needed'
\echo ''
