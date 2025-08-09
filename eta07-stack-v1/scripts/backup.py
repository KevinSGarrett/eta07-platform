import os, subprocess, sys, datetime

def run(cmd, env=None):
    print("+", " ".join(cmd))
    subprocess.check_call(cmd, env=env or os.environ.copy())

if __name__ == "__main__":
    ts = datetime.datetime.utcnow().strftime("%Y-%m-%d_%H-%M-%S")
    db = os.getenv("POSTGRES_DB","eta07_prod")
    backup_bucket = os.getenv("BACKUP_S3_BUCKET")
    copy_region = os.getenv("AWS_BACKUP_COPY_REGION","").strip()
    if not backup_bucket:
        print("BACKUP_S3_BUCKET not set", file=sys.stderr)
        sys.exit(1)
    out = f"/tmp/{db}_{ts}.sql.gz"
    pg_cmd = ["pg_dump", "-h", os.getenv("POSTGRES_HOST","localhost"), "-p", os.getenv("POSTGRES_PORT","5432"),
              "-U", os.getenv("POSTGRES_USER","directus"), db]
    env = os.environ.copy()
    env["PGPASSWORD"] = os.getenv("POSTGRES_PASSWORD","")
    gzip = ["gzip", "-9"]
    with subprocess.Popen(pg_cmd, env=env, stdout=subprocess.PIPE) as p1:
        with open(out, "wb") as f:
            subprocess.check_call(gzip, stdin=p1.stdout, stdout=f)
    # Upload to S3
    run(["aws","s3","cp", out, f"s3://{backup_bucket}/{os.path.basename(out)}"])
    # Optional cross-region copy (requires -crr bucket created with replication or a second bucket name convention)
    if copy_region:
        key = os.path.basename(out)
        run(["aws","s3","cp", f"s3://{backup_bucket}/{key}", f"s3://{backup_bucket}-crr/{key}", "--source-region", os.getenv("AWS_REGION","us-east-1"), "--region", copy_region])
    print("Backup complete.")
