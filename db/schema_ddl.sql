
-- Core schema (abbreviated; extend as needed)
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pgaudit;

DO $$ BEGIN
  CREATE TYPE service_type AS ENUM ('lab','hvac','collections','tenant_screening','employment_screening');
EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN
  CREATE TYPE lead_stage AS ENUM ('new','cleaning','attempted','contacted','nurturing','appointment_set','converted','disqualified');
EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN
  CREATE TYPE last_outcome AS ENUM ('no_answer','not_interested','interested','appointment_scheduled','converted');
EXCEPTION WHEN duplicate_object THEN null; END $$;

CREATE TABLE IF NOT EXISTS public.leads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_name text,
  contact_full_name text,
  job_title text,
  email text,
  phone_e164 text,
  website text,
  facebook_url text,
  linkedin_url text,
  instagram_url text,
  lead_stage lead_stage NOT NULL DEFAULT 'new',
  last_outcome last_outcome,
  tags text[] NOT NULL DEFAULT '{}',
  crm_id text,
  last_activity_at timestamptz,
  source_batch_id text,
  raw_json jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.lead_services (
  lead_id uuid REFERENCES public.leads(id) ON DELETE CASCADE,
  service service_type NOT NULL,
  service_status text,
  assigned_to text,
  score int,
  score_band text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (lead_id, service)
);

CREATE TABLE IF NOT EXISTS public.contacts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id uuid REFERENCES public.leads(id) ON DELETE CASCADE,
  type text CHECK (type IN ('email','phone','fax','other')) NOT NULL,
  subtype text,
  value text NOT NULL,
  is_primary boolean NOT NULL DEFAULT false,
  verified_at timestamptz,
  provenance text NOT NULL DEFAULT 'import',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.addresses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id uuid REFERENCES public.leads(id) ON DELETE CASCADE,
  type text CHECK (type IN ('physical','mailing','enriched')) NOT NULL DEFAULT 'physical',
  street text,
  city text,
  state text,
  postal_code text,
  country text DEFAULT 'US',
  zip_centroid_id text,
  validated boolean NOT NULL DEFAULT false,
  provenance text NOT NULL DEFAULT 'import',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id uuid REFERENCES public.leads(id) ON DELETE CASCADE,
  s3_key text NOT NULL,
  file_name text NOT NULL,
  mime_type text NOT NULL,
  size_bytes bigint NOT NULL,
  provenance text NOT NULL DEFAULT 'manual',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE SCHEMA IF NOT EXISTS staging;
CREATE TABLE IF NOT EXISTS staging.upload_batches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source text,
  service_guess service_type,
  row_count int,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS staging.rows_raw (
  batch_id uuid REFERENCES staging.upload_batches(id) ON DELETE CASCADE,
  row_num int NOT NULL,
  raw_json jsonb NOT NULL,
  PRIMARY KEY (batch_id, row_num)
);

CREATE TABLE IF NOT EXISTS public.audit_log (
  id bigserial PRIMARY KEY,
  actor_email text,
  actor_role text,
  action text,
  entity text,
  entity_id text,
  meta jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.export_logs (
  id bigserial PRIMARY KEY,
  actor_email text,
  actor_role text,
  filter text,
  columns text[],
  row_count int,
  file_type text,
  meta jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE SCHEMA IF NOT EXISTS enrich;
CREATE TABLE IF NOT EXISTS enrich.enrichment_jobs (
  job_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  requested_by text NOT NULL,
  requested_role text NOT NULL,
  count_requested int NOT NULL,
  count_queued int NOT NULL DEFAULT 0,
  count_succeeded int NOT NULL DEFAULT 0,
  count_failed int NOT NULL DEFAULT 0,
  count_cached int NOT NULL DEFAULT 0,
  count_skipped int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  finished_at timestamptz
);
CREATE TABLE IF NOT EXISTS enrich.enrichment_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id uuid REFERENCES enrich.enrichment_jobs(job_id) ON DELETE CASCADE,
  lead_id uuid REFERENCES public.leads(id) ON DELETE CASCADE,
  input_json jsonb NOT NULL,
  requested_by text NOT NULL,
  requested_role text NOT NULL,
  status text NOT NULL DEFAULT 'queued',
  error_code text,
  created_at timestamptz NOT NULL DEFAULT now(),
  run_at timestamptz,
  retry_count int NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS enrich.enrichment_results_raw (
  request_id uuid PRIMARY KEY REFERENCES enrich.enrichment_requests(id) ON DELETE CASCADE,
  provider text NOT NULL DEFAULT 'pdl',
  http_code int,
  credits_used numeric,
  response_json jsonb NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now(),
  hash text
);
CREATE TABLE IF NOT EXISTS enrich.enrichment_merges (
  merge_id bigserial PRIMARY KEY,
  request_id uuid REFERENCES enrich.enrichment_requests(id) ON DELETE CASCADE,
  table_name text, pk_value text, field text,
  old_value text, new_value text,
  merge_rule text, merged_by text,
  merged_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS enrich.enrichment_cache (
  lookup_key text PRIMARY KEY,
  provider text NOT NULL DEFAULT 'pdl',
  response_json jsonb NOT NULL,
  confidence numeric,
  last_used_at timestamptz NOT NULL DEFAULT now()
);

-- Helper views/functions (quota/cooldown) would be added here in full implementation.
