-- FIVUCSAS pgvector Setup Script
-- This script ensures pgvector extension is configured correctly for face embeddings

-- Enable pgvector extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS vector;

-- Create helper function to check vector similarity
-- This can be used for manual testing and debugging
CREATE OR REPLACE FUNCTION check_embedding_similarity(
    user1_id UUID,
    user2_id UUID,
    tenant_filter UUID DEFAULT NULL
)
RETURNS TABLE (
    user1 UUID,
    user2 UUID,
    cosine_distance FLOAT,
    cosine_similarity FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        b1.user_id AS user1,
        b2.user_id AS user2,
        b1.embedding <=> b2.embedding AS cosine_distance,
        1.0 - (b1.embedding <=> b2.embedding) AS cosine_similarity
    FROM biometric_data b1
    CROSS JOIN biometric_data b2
    WHERE b1.user_id = user1_id
      AND b2.user_id = user2_id
      AND (tenant_filter IS NULL OR (b1.tenant_id = tenant_filter AND b2.tenant_id = tenant_filter))
      AND b1.biometric_type = 'FACE'
      AND b2.biometric_type = 'FACE'
      AND b1.is_active = TRUE
      AND b2.is_active = TRUE
      AND b1.deleted_at IS NULL
      AND b2.deleted_at IS NULL
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Create function to find similar faces (for testing 1:N identification)
CREATE OR REPLACE FUNCTION find_similar_faces(
    query_embedding vector,
    similarity_threshold FLOAT DEFAULT 0.6,
    result_limit INTEGER DEFAULT 5,
    tenant_filter UUID DEFAULT NULL
)
RETURNS TABLE (
    user_id UUID,
    distance FLOAT,
    similarity FLOAT,
    embedding_model VARCHAR(50),
    quality_score FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        bd.user_id,
        bd.embedding <=> query_embedding AS distance,
        1.0 - (bd.embedding <=> query_embedding) AS similarity,
        bd.embedding_model,
        bd.quality_score
    FROM biometric_data bd
    WHERE (tenant_filter IS NULL OR bd.tenant_id = tenant_filter)
      AND bd.biometric_type = 'FACE'
      AND bd.is_active = TRUE
      AND bd.deleted_at IS NULL
      AND bd.embedding <=> query_embedding < similarity_threshold
    ORDER BY distance ASC
    LIMIT result_limit;
END;
$$ LANGUAGE plpgsql;

-- Create view for active embeddings (convenient for queries)
CREATE OR REPLACE VIEW active_face_embeddings AS
SELECT
    id,
    user_id,
    tenant_id,
    embedding,
    embedding_model,
    embedding_dimension,
    quality_score,
    liveness_verified,
    is_primary,
    created_at,
    updated_at
FROM biometric_data
WHERE biometric_type = 'FACE'
  AND is_active = TRUE
  AND deleted_at IS NULL;

-- Create statistics view for monitoring
CREATE OR REPLACE VIEW biometric_statistics AS
SELECT
    tenant_id,
    embedding_model,
    COUNT(*) AS total_embeddings,
    AVG(quality_score) AS avg_quality_score,
    MIN(quality_score) AS min_quality_score,
    MAX(quality_score) AS max_quality_score,
    COUNT(*) FILTER (WHERE liveness_verified = TRUE) AS liveness_verified_count,
    COUNT(*) FILTER (WHERE is_primary = TRUE) AS primary_embeddings_count
FROM biometric_data
WHERE biometric_type = 'FACE'
  AND is_active = TRUE
  AND deleted_at IS NULL
GROUP BY tenant_id, embedding_model;

-- Grant permissions (adjust based on your user setup)
-- Assuming the application uses 'postgres' user in development
GRANT SELECT, INSERT, UPDATE, DELETE ON biometric_data TO postgres;
GRANT SELECT, INSERT, UPDATE, DELETE ON liveness_attempts TO postgres;
GRANT SELECT, INSERT, UPDATE, DELETE ON biometric_verification_logs TO postgres;
GRANT SELECT ON active_face_embeddings TO postgres;
GRANT SELECT ON biometric_statistics TO postgres;

-- Create indexes for common query patterns (if not already created in V4 migration)
-- These are in addition to the vector similarity index

-- Index for finding user's latest embedding
CREATE INDEX IF NOT EXISTS idx_biometric_user_created_at
    ON biometric_data (user_id, created_at DESC)
    WHERE biometric_type = 'FACE' AND is_active = TRUE AND deleted_at IS NULL;

-- Index for quality filtering
CREATE INDEX IF NOT EXISTS idx_biometric_quality
    ON biometric_data (quality_score)
    WHERE biometric_type = 'FACE' AND is_active = TRUE AND deleted_at IS NULL;

-- Index for liveness filtering
CREATE INDEX IF NOT EXISTS idx_biometric_liveness
    ON biometric_data (liveness_verified)
    WHERE biometric_type = 'FACE' AND is_active = TRUE AND deleted_at IS NULL;

-- Index for model filtering (useful when migrating between models)
CREATE INDEX IF NOT EXISTS idx_biometric_model
    ON biometric_data (embedding_model)
    WHERE biometric_type = 'FACE' AND is_active = TRUE AND deleted_at IS NULL;

\echo 'pgvector setup completed successfully!';
\echo 'Helper functions created: check_embedding_similarity, find_similar_faces';
\echo 'Views created: active_face_embeddings, biometric_statistics';
