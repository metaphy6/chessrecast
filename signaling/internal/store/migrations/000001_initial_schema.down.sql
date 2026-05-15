-- 000001_initial_schema.down.sql
-- down_migration_blocked: true
-- This migration is IRREVERSIBLE.
-- Dropping the accounts/offers tables would destroy production data.
-- Intentional non-operation: any down migration attempt is a configuration error.
SELECT 1; -- no-op; the migrate tool will succeed without destroying data
