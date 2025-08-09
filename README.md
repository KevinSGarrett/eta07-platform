# ETA07 Stack v1 (Starter Pack)
Generated: 2025-08-09T07:02:43.701816Z

This starter pack contains:
- **db/schema.sql** — canonical tables, link tables, service extensions, enums, RLS policies, roles, quotas, audit tables.
- **scripts/setup_db.py** — bootstrap DB (roles, RLS, functions) from environment.
- **scripts/etl_import.py** — staging import, cleaning, dedupe, promotion to normalized tables.
- **scripts/backup.py** — nightly `pg_dump` to S3, optional cross-region copy.
- **scripts/monitoring.py** — export spike detector, failed-login watcher, WAL lag checks; emails alerts.
- **scripts/audit_summary.py** — monthly audit summary generator (CSV + optional PDF) and uploader.
- **directus/seed.json** — Directus collections, roles, presets, and dashboards template (import via Directus API or UI).
- **data/zip_centroids_us.csv** — placeholder (you can replace with a full centroid dataset later).

## Quick Start
1. Copy `.env.example` to `.env` and fill values.
2. Run `python3 scripts/setup_db.py` to create roles, tables, policies.
3. Use `scripts/etl_import.py` to load a CSV into staging and promote to normalized tables.
4. Schedule `scripts/backup.py` nightly (UTC 06:00 ≈ midnight America/Chicago).
5. Schedule `scripts/monitoring.py` every 5–15 minutes for alerts.
6. Import `directus/seed.json` (or run a separate seeding script) to configure Directus UI.

## Notes
- Export watermarking: embedded visible header + hidden metadata + HMAC signature; >10k rows auto-ZIP with AES password.
- RLS masks email/social for Sales Team & Sales Team Lead; Collections Manager is scoped to Collections only.
- All limits are enforced at the DB layer with triggers/functions + audit logs.
