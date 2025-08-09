
# Setup Guide (Complete v1)

1) Terraform
- Fill iac/variables.tf values for your VPC/subnet/zone.
- `cd iac && terraform init && terraform plan && terraform apply`

2) DNS
- Confirm `data.eta07data.com` points to the EC2 IP output by Terraform.

3) Docker
- On EC2: install docker + compose; copy `deploy/*`; create `.env` from `deploy/directus.env.example`.
- `docker compose up -d`

4) Database
- `psql` into the db container; run `db/schema_ddl.sql` and `db/roles_permissions.sql`.
- Create Directus admin; configure roles & permissions in UI.

5) SES
- Verify domain + DKIM/SPF/DMARC; add SMTP creds to env; test emails.

6) Backups
- Set BACKUP_S3_BUCKET; schedule `scripts/db_backup.py` nightly (cron).

7) Enrichment
- Add PDL key; wire `scripts/enrichment_worker.py` + `scripts/enqueue_api.py`.
