import os, subprocess, datetime

ALERTS = [e.strip() for e in os.getenv("ALERT_EMAILS","").split(",") if e.strip()]

def psql(query):
    cmd = ["psql","-h",os.getenv("POSTGRES_HOST","localhost"),"-p",os.getenv("POSTGRES_PORT","5432"),
           "-U",os.getenv("POSTGRES_USER","directus"),"-d",os.getenv("POSTGRES_DB","eta07_prod"),
           "-v","ON_ERROR_STOP=1","-t","-A","-F","|","-c",query]
    env = os.environ.copy()
    env["PGPASSWORD"] = os.getenv("POSTGRES_PASSWORD","")
    out = subprocess.check_output(cmd, env=env).decode().strip()
    return out

def send(subject, body):
    # Placeholder: integrate SES or SMTP later
    print("ALERT:", subject)
    print(body)

if __name__ == "__main__":
    now = datetime.datetime.utcnow().isoformat()+"Z"
    # Export spike: >2000 rows in last 15min by non-exec
    q = """
    SELECT username, role_name, sum(row_count) AS rows, min(exported_at), max(exported_at)
    FROM csv_export_logs
    WHERE exported_at > now() - interval '15 minutes'
      AND role_name NOT IN ('super_admin','ceo','cto')
    GROUP BY username, role_name
    HAVING sum(row_count) > 2000;
    """
    res = psql(q)
    if res:
        send(f"[ETA07] Export spike detected {now}", res)

    print("Monitoring pass complete.")
