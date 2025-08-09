
-- Roles & grants (abbreviated – expand per your policy)
DO $$ BEGIN CREATE ROLE super_admin; EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE ROLE ceo; EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE ROLE cto; EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE ROLE sales_manager; EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE ROLE collections_manager; EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE ROLE compliance_manager; EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE ROLE lab_sales_manager; EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE ROLE sales_team_lead; EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE ROLE sales_team; EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE ROLE dev_maint; EXCEPTION WHEN duplicate_object THEN null; END $$;

GRANT USAGE ON SCHEMA public, staging, enrich TO PUBLIC;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO super_admin, ceo;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO cto, sales_manager, collections_manager, compliance_manager, lab_sales_manager, sales_team_lead, sales_team, dev_maint;

-- TODO: Implement RLS policies and masking views per role.
