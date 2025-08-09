-- === Core enums ===
DO $$ BEGIN
  CREATE TYPE service_type AS ENUM ('lab','hvac','collections','tenant_screening','employment_screening');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE lead_stage AS ENUM ('new','cleaning','attempted','contacted','nurturing','appointment_set','converted','disqualified');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE outcome AS ENUM ('no_answer','not_interested','interested','appointment_scheduled','converted');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- === Roles ===
DO $$ BEGIN
  CREATE ROLE super_admin;
  CREATE ROLE ceo;
  CREATE ROLE cto;
  CREATE ROLE sales_manager;
  CREATE ROLE collections_manager;
  CREATE ROLE compliance_manager;
  CREATE ROLE lab_sales_manager;
  CREATE ROLE sales_team_lead;
  CREATE ROLE sales_team;
  CREATE ROLE dev_maint;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Application login role template (no superuser)
DO $$ BEGIN
  CREATE ROLE app_rw LOGIN PASSWORD 'CHANGE_ME_STRONG';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- === Audit & quotas support ===
CREATE TABLE IF NOT EXISTS audit_log (
  id BIGSERIAL PRIMARY KEY,
  username TEXT,
  role_name TEXT,
  event_type TEXT,     -- login, read, write, delete, export, role_change, schema_change, backup, restore
  table_name TEXT,
  row_id TEXT,
  details JSONB,
  client_ip INET,
  occurred_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS csv_export_logs (
  id BIGSERIAL PRIMARY KEY,
  username TEXT NOT NULL,
  role_name TEXT NOT NULL,
  exported_at TIMESTAMPTZ DEFAULT now(),
  table_name TEXT NOT NULL,
  filter TEXT,
  columns TEXT[],
  row_count INT NOT NULL,
  file_type TEXT NOT NULL
);

-- Optional configurable limits per role (fallback to env vars if not set)
CREATE TABLE IF NOT EXISTS role_export_limits (
  role_name TEXT PRIMARY KEY,
  daily_limit INT,
  weekly_limit INT
);

-- === Canonical leads ===
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE IF NOT EXISTS leads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_name TEXT,
  contact_full_name TEXT,
  job_title TEXT,
  phone_e164 TEXT,
  email TEXT,
  website TEXT,
  street TEXT,
  city TEXT,
  state TEXT,
  postal_code TEXT,
  country TEXT DEFAULT 'US',
  facebook_url TEXT,
  linkedin_url TEXT,
  instagram_url TEXT,
  lead_stage lead_stage DEFAULT 'new',
  last_outcome outcome,
  tags TEXT[] DEFAULT '{}',
  owner_role TEXT,
  owner_user TEXT,
  crm_id TEXT,
  last_activity_at TIMESTAMPTZ,
  source_batch_id TEXT,
  raw_json JSONB,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_leads_email ON leads (email);
CREATE INDEX IF NOT EXISTS idx_leads_phone ON leads (phone_e164);
CREATE INDEX IF NOT EXISTS idx_leads_city_state ON leads (city, state);
CREATE INDEX IF NOT EXISTS idx_leads_stage ON leads (lead_stage);
CREATE INDEX IF NOT EXISTS idx_leads_tags_gin ON leads USING GIN (tags);
CREATE INDEX IF NOT EXISTS idx_leads_rawjson_gin ON leads USING GIN (raw_json);

-- Link table
CREATE TABLE IF NOT EXISTS lead_services (
  lead_id UUID REFERENCES leads(id) ON DELETE CASCADE,
  service service_type NOT NULL,
  service_status TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (lead_id, service)
);

-- === Service extension tables ===
-- Lab details
CREATE TABLE IF NOT EXISTS lab_lead_details (
  lead_id UUID PRIMARY KEY REFERENCES leads(id) ON DELETE CASCADE,
  accepts_medicare BOOLEAN,
  accepts_medicaid BOOLEAN,
  accepts_blue_cross BOOLEAN,
  accepts_united BOOLEAN,
  insurance_accepted TEXT,
  specialties TEXT,
  conditions TEXT,
  procedures TEXT,
  doctors_count INT,
  hours TEXT,
  extras_json JSONB
);

-- HVAC details (property-centric)
CREATE TABLE IF NOT EXISTS hvac_lead_details (
  lead_id UUID PRIMARY KEY REFERENCES leads(id) ON DELETE CASCADE,
  account_number TEXT,
  owner_name TEXT,
  mailing_street TEXT,
  mailing_city TEXT,
  mailing_state TEXT,
  mailing_zip TEXT,
  legal_description TEXT,
  property_street TEXT,
  property_city TEXT,
  property_state TEXT,
  property_zip TEXT,
  land_area NUMERIC,
  total_living_area NUMERIC,
  year_built INT,
  permits_count INT,
  lead_score INT,
  phone_lookup TEXT,
  extras_json JSONB
);

-- Collections details (business directory style)
CREATE TABLE IF NOT EXISTS collections_lead_details (
  lead_id UUID PRIMARY KEY REFERENCES leads(id) ON DELETE CASCADE,
  description TEXT,
  employer_size TEXT,
  rating NUMERIC,
  user_ratings_total INT,
  opening_hours TEXT,
  business_status TEXT,
  price_level TEXT,
  social_twitter TEXT,
  social_snapchat TEXT,
  social_pinterest TEXT,
  extras_json JSONB
);

-- === Staging (example raw landing table) ===
CREATE SCHEMA IF NOT EXISTS staging;
CREATE TABLE IF NOT EXISTS staging.upload_raw (
  id BIGSERIAL PRIMARY KEY,
  service_guess TEXT,
  source_file TEXT,
  raw_row JSONB NOT NULL,
  ingested_at TIMESTAMPTZ DEFAULT now(),
  processed BOOLEAN DEFAULT FALSE,
  quality_flag TEXT
);

-- === Export quota enforcement ===
CREATE OR REPLACE FUNCTION get_export_limit(p_role TEXT, p_window TEXT)
RETURNS INT LANGUAGE sql AS $$
  SELECT COALESCE(
    CASE WHEN p_window='daily' THEN daily_limit ELSE weekly_limit END,
    CASE 
      WHEN p_role='sales_team' AND p_window='daily' THEN 75
      WHEN p_role='sales_team_lead' AND p_window='weekly' THEN 500
      ELSE NULL
    END
  )
  FROM role_export_limits WHERE role_name = p_role;
$$;

CREATE OR REPLACE FUNCTION enforce_export_quota()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  dlim INT;
  wlim INT;
  dcount INT;
  wcount INT;
BEGIN
  dlim := get_export_limit(NEW.role_name, 'daily');
  wlim := get_export_limit(NEW.role_name, 'weekly');
  IF dlim IS NOT NULL THEN
    SELECT COUNT(*) INTO dcount
    FROM csv_export_logs
    WHERE role_name = NEW.role_name
      AND username = NEW.username
      AND exported_at::date = NEW.exported_at::date;
    IF dcount >= dlim THEN
      RAISE EXCEPTION 'Daily export limit reached for role %', NEW.role_name;
    END IF;
  END IF;
  IF wlim IS NOT NULL THEN
    SELECT COUNT(*) INTO wcount
    FROM csv_export_logs
    WHERE role_name = NEW.role_name
      AND username = NEW.username
      AND exported_at >= (NEW.exported_at - INTERVAL '7 days');
    IF wcount >= wlim THEN
      RAISE EXCEPTION 'Weekly export limit reached for role %', NEW.role_name;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_export_quota ON csv_export_logs;
CREATE TRIGGER trg_enforce_export_quota
  BEFORE INSERT ON csv_export_logs
  FOR EACH ROW
  EXECUTE FUNCTION enforce_export_quota();

-- === Masked view for Sales Team roles ===
CREATE OR REPLACE VIEW leads_masked AS
  SELECT 
    id, company_name, contact_full_name, job_title,
    NULL::TEXT AS email,
    NULL::TEXT AS facebook_url,
    NULL::TEXT AS linkedin_url,
    NULL::TEXT AS instagram_url,
    phone_e164, website, street, city, state, postal_code, country,
    lead_stage, last_outcome, tags, owner_role, owner_user, crm_id, last_activity_at,
    source_batch_id, created_at, updated_at
  FROM leads;

-- === RLS Policies ===
ALTER TABLE leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE lead_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE lab_lead_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE hvac_lead_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE collections_lead_details ENABLE ROW LEVEL SECURITY;

-- Default deny
DO $$ BEGIN
  EXECUTE 'CREATE POLICY deny_all_leads ON leads FOR ALL TO PUBLIC USING (false)';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Sales Manager: all leads read
DO $$ BEGIN
  EXECUTE 'CREATE POLICY sales_manager_read ON leads FOR SELECT TO sales_manager USING (true)';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Collections Manager: only collections
DO $$ BEGIN
  EXECUTE 'CREATE POLICY collections_manager_read ON leads FOR SELECT TO collections_manager USING (id IN (SELECT lead_id FROM lead_services WHERE service = ''collections''))';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Execs: full read/write
DO $$ BEGIN
  EXECUTE 'CREATE POLICY execs_rw ON leads FOR ALL TO super_admin,ceo USING (true) WITH CHECK (true)';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- CTO/Compliance: read; Compliance can write
DO $$ BEGIN
  EXECUTE 'CREATE POLICY cto_read ON leads FOR SELECT TO cto USING (true)';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  EXECUTE 'CREATE POLICY compliance_rw ON leads FOR ALL TO compliance_manager USING (true) WITH CHECK (true)';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Sales Team & Sales Team Lead: only masked view will be granted
GRANT SELECT ON leads_masked TO sales_team, sales_team_lead;

-- Basic grants
GRANT USAGE ON SCHEMA public TO super_admin, ceo, cto, sales_manager, collections_manager, compliance_manager, lab_sales_manager, dev_maint;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO super_admin, ceo, cto, sales_manager, collections_manager, compliance_manager, lab_sales_manager;
GRANT INSERT, UPDATE, DELETE ON leads TO super_admin, ceo, compliance_manager;
GRANT SELECT ON audit_log, csv_export_logs TO super_admin, ceo, cto;

-- === Full-text search support ===
DO $$ BEGIN
  ALTER TABLE leads ADD COLUMN IF NOT EXISTS search_tsv tsvector;
EXCEPTION WHEN duplicate_column THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_leads_tsv ON leads USING GIN (search_tsv);

CREATE OR REPLACE FUNCTION leads_tsv_trigger() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.search_tsv := to_tsvector('simple',
    coalesce(NEW.company_name,'') || ' ' ||
    coalesce(NEW.contact_full_name,'') || ' ' ||
    coalesce(NEW.email,'') || ' ' ||
    coalesce(NEW.phone_e164,'') || ' ' ||
    coalesce(NEW.website,'')
  );
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS tsvupdate ON leads;
CREATE TRIGGER tsvupdate BEFORE INSERT OR UPDATE ON leads
  FOR EACH ROW EXECUTE FUNCTION leads_tsv_trigger();

-- === ZIP centroid lookup (placeholder table) ===
CREATE TABLE IF NOT EXISTS zip_centroids (
  zip TEXT PRIMARY KEY,
  lat NUMERIC,
  lng NUMERIC
);
