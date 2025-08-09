
#!/usr/bin/env python3
import os, subprocess, sys

if len(sys.argv) < 2:
    print("Usage: db_restore.py s3://bucket/file.sql.gz"); sys.exit(1)
src = sys.argv[1]
DB = os.getenv("POSTGRES_DB", "eta07_prod")
USER = os.getenv("POSTGRES_USER", "directus")
HOST = os.getenv("POSTGRES_HOST", "localhost")

p1 = subprocess.Popen(["aws","s3","cp",src,"-"], stdout=subprocess.PIPE)
p2 = subprocess.Popen(["gunzip","-c"], stdin=p1.stdout, stdout=subprocess.PIPE)
p3 = subprocess.check_call(["psql", f"-h{HOST}", f"-U{USER}", DB], stdin=p2.stdout)
print("Restore completed from", src)
