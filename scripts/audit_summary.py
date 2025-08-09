import os, subprocess, datetime

def psql(query):
    cmd = ["psql","-h",os.getenv("POSTGRES_HOST","localhost"),"-p",os.getenv("POSTGRES_PORT","5432"),
           "-U",os.getenv("POSTGRES_USER","directus"),"-d",os.getenv("POSTGRES_DB","eta07_prod"),
           "-v","ON_ERROR_STOP=1","-t","-A","-F",",","-c",query]
    env = os.environ.copy()
    env["PGPASSWORD"] = os.getenv("POSTGRES_PASSWORD","")
    out = subprocess.check_output(cmd, env=env).decode().strip()
    return out

if __name__ == "__main__":
    today = datetime.date.today()
    first = (today.replace(day=1) - datetime.timedelta(days=1)).replace(day=1)
    last = (today.replace(day=1) - datetime.timedelta(days=1))
    q = f"""
    SELECT role_name, event_type, count(*)
    FROM audit_log
    WHERE occurred_at::date BETWEEN '{first}' AND '{last}'
    GROUP BY role_name, event_type
    ORDER BY role_name, event_type;
    """
    csv = psql(q)
    out_path = f"/mnt/data/audit_summary_{first}_{last}.csv"
    with open(out_path,"w") as f:
        f.write("role_name,event_type,count\n")
        if csv:
            f.write(csv + "\n")
    print("Wrote", out_path)
