-- ADR-002: PostgreSQL + PostGIS Target Schema & Row-Level Security (RLS)
-- Bassem Sales Platform (Sprints 10 & 11)

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ==========================================
-- 1. Multi-Tenant Core
-- ==========================================
CREATE TABLE IF NOT EXISTS tenants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==========================================
-- 2. Users & Field Agents
-- ==========================================
CREATE TABLE IF NOT EXISTS users (
  id BIGSERIAL PRIMARY KEY,
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  username TEXT NOT NULL,
  name TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('owner', 'admin', 'regional_manager', 'supervisor', 'technician', 'agent')),
  agent_id BIGINT NULL,
  branch TEXT NULL,
  supervised_agent_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
  salt TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (tenant_id, email)
);

CREATE TABLE IF NOT EXISTS agents (
  id BIGSERIAL PRIMARY KEY,
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  area TEXT NULL,
  phone TEXT NULL,
  email TEXT NULL,
  login_email TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==========================================
-- 3. Batches & Chillers (PostGIS Geospatial)
-- ==========================================
CREATE TABLE IF NOT EXISTS batches (
  id BIGSERIAL PRIMARY KEY,
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  filename TEXT NOT NULL,
  uploaded_by TEXT NULL,
  row_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS chillers (
  id BIGSERIAL PRIMARY KEY,
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  batch_id BIGINT NULL REFERENCES batches(id) ON DELETE SET NULL,
  chiller_code TEXT NOT NULL,
  branch TEXT NULL,
  customer_code TEXT NULL,
  customer_name TEXT NULL,
  customer_address TEXT NULL,
  customer_type TEXT NULL,
  chiller_type TEXT NULL,
  chiller_status TEXT NULL,
  condition TEXT NOT NULL DEFAULT 'Operational',
  serial_number TEXT NULL,
  latitude DOUBLE PRECISION NULL,
  longitude DOUBLE PRECISION NULL,
  location GEOGRAPHY(POINT, 4326) NULL,
  ytd_invoice NUMERIC(14, 2) NOT NULL DEFAULT 0,
  avg_achievement NUMERIC(6, 2) NOT NULL DEFAULT 0,
  raw_data_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (tenant_id, chiller_code)
);

CREATE INDEX IF NOT EXISTS idx_chillers_location_gist
  ON chillers USING GIST (location);

CREATE INDEX IF NOT EXISTS idx_chillers_tenant_branch
  ON chillers (tenant_id, branch);

-- ==========================================
-- 4. Territory Assignments
-- ==========================================
CREATE TABLE IF NOT EXISTS assignments (
  id BIGSERIAL PRIMARY KEY,
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  agent_id BIGINT NOT NULL REFERENCES agents(id) ON DELETE CASCADE,
  chiller_code TEXT NULL,
  customer_name TEXT NULL,
  assigned_by TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_assignments_tenant_agent
  ON assignments (tenant_id, agent_id);

-- ==========================================
-- 5. Dynamic Audit Forms & Responses
-- ==========================================
CREATE TABLE IF NOT EXISTS forms (
  id BIGSERIAL PRIMARY KEY,
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT NULL,
  fields JSONB NOT NULL DEFAULT '[]'::jsonb,
  assigned_agent_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS form_responses (
  id BIGSERIAL PRIMARY KEY,
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  form_id BIGINT NOT NULL REFERENCES forms(id) ON DELETE CASCADE,
  agent_id BIGINT NULL REFERENCES agents(id) ON DELETE SET NULL,
  chiller_code TEXT NULL,
  customer_name TEXT NULL,
  answers JSONB NOT NULL DEFAULT '{}'::jsonb,
  attachments JSONB NOT NULL DEFAULT '[]'::jsonb,
  status TEXT NOT NULL DEFAULT 'submitted' CHECK (status IN ('submitted', 'approved', 'reopened')),
  admin_feedback TEXT NULL,
  ai_insights JSONB NULL,
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reviewed_at TIMESTAMPTZ NULL
);

-- ==========================================
-- 6. Maintenance & Support Tickets
-- ==========================================
CREATE TABLE IF NOT EXISTS tickets (
  id BIGSERIAL PRIMARY KEY,
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  chiller_code TEXT NOT NULL,
  customer_name TEXT NULL,
  branch TEXT NULL,
  priority TEXT NOT NULL DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'critical')),
  category TEXT NOT NULL DEFAULT 'maintenance',
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'resolved', 'closed')),
  description TEXT NOT NULL,
  assigned_to TEXT NULL,
  created_by TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==========================================
-- 7. Enterprise ERP / DMS Webhooks & Sync Logs
-- ==========================================
CREATE TABLE IF NOT EXISTS webhooks (
  id BIGSERIAL PRIMARY KEY,
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  url TEXT NOT NULL,
  events JSONB NOT NULL DEFAULT '[]'::jsonb,
  signing_secret_hash TEXT NOT NULL,
  secret_last4 TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_by TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS erp_sync_logs (
  id BIGSERIAL PRIMARY KEY,
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  source TEXT NOT NULL DEFAULT 'DMS/ERP',
  mode TEXT NOT NULL DEFAULT 'incremental',
  status TEXT NOT NULL DEFAULT 'completed',
  chillers_synced INTEGER NOT NULL DEFAULT 0,
  tickets_synced INTEGER NOT NULL DEFAULT 0,
  invoices_synced INTEGER NOT NULL DEFAULT 0,
  triggered_by TEXT NULL,
  triggered_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==========================================
-- 8. Row-Level Security (Tenant Isolation)
-- ==========================================
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE agents ENABLE ROW LEVEL SECURITY;
ALTER TABLE batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE chillers ENABLE ROW LEVEL SECURITY;
ALTER TABLE assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE forms ENABLE ROW LEVEL SECURITY;
ALTER TABLE form_responses ENABLE ROW LEVEL SECURITY;
ALTER TABLE tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE webhooks ENABLE ROW LEVEL SECURITY;
ALTER TABLE erp_sync_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_users ON users
  USING (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

CREATE POLICY tenant_isolation_agents ON agents
  USING (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

CREATE POLICY tenant_isolation_batches ON batches
  USING (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

CREATE POLICY tenant_isolation_chillers ON chillers
  USING (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

CREATE POLICY tenant_isolation_assignments ON assignments
  USING (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

CREATE POLICY tenant_isolation_forms ON forms
  USING (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

CREATE POLICY tenant_isolation_form_responses ON form_responses
  USING (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

CREATE POLICY tenant_isolation_tickets ON tickets
  USING (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

CREATE POLICY tenant_isolation_webhooks ON webhooks
  USING (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);

CREATE POLICY tenant_isolation_erp_sync_logs ON erp_sync_logs
  USING (tenant_id = NULLIF(current_setting('app.current_tenant_id', true), '')::UUID);
