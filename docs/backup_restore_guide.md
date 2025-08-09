
# Backup & Restore Guide

- Nightly backup: schedule `scripts/db_backup.py` (00:00 America/Chicago).
- Restore: run `scripts/db_restore.py s3://<bucket>/<file>.sql.gz` into staging DB.
