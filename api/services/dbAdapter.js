import fs from 'fs';
import path from 'path';
import { isCloudStorageConfigured } from '../cloud_storage.js';

const POSTGIS_SCHEMA_REL_PATH = 'scripts/migrate_to_postgres.sql';

/**
 * ADR-002 Database Adapter status helper.
 * Reports current runtime persistence engine and PostgreSQL/PostGIS readiness
 * without exposing sensitive connection strings or credentials.
 */
export function getDbAdapterStatus() {
  const hasDatabaseUrl = Boolean(process.env.DATABASE_URL && process.env.DATABASE_URL.trim());
  const schemaPath = path.resolve(POSTGIS_SCHEMA_REL_PATH);

  return {
    adr: 'ADR-002',
    engine: hasDatabaseUrl ? 'postgres-ready' : 'json-blob',
    activePersistence: isCloudStorageConfigured() ? 'vercel-blob' : 'local-json',
    postgresConfigured: hasDatabaseUrl,
    postgisSchemaPath: POSTGIS_SCHEMA_REL_PATH,
    postgisSchemaAvailable: fs.existsSync(schemaPath)
  };
}
