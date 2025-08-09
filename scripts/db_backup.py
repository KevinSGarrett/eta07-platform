
#!/usr/bin/env python3
import os, subprocess, datetime, sys

DB = os.getenv("POSTGRES_DB", "eta07_prod")
USER = os.getenv("POSTGRES_USER", "directus")
HOST = os.getenv("POSTGRES_HOST", "localhost")
BACKUP_BUCKET = os.getenv("BACKUP_S3_BUCKET")
if not BACKUP_BUCKET:
    print("BACKUP_S3_BUCKET not set"); sys.exit(1)

ts = datetime.datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
fname = f"{DB}-{ts}.sql.gz"
dump = subprocess.Popen(["pg_dump", f"-h{HOST}", f"-U{USER}", DB], stdout=subprocess.PIPE)
gzip = subprocess.Popen(["gzip","-9"], stdin=dump.stdout, stdout=subprocess.PIPE)
aws = subprocess.check_call(["aws","s3","cp","-", f"s3://{BACKUP_BUCKET}/{fname}"], stdin=gzip.stdout)
print("Backup uploaded:", fname)
