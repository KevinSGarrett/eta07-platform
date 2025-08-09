import os, csv, json, re, argparse, subprocess

JUNK_EMAILS = {"user@domain.com","example@example.com"}
BAD_EMAIL_DOMAINS = {"mailinator.com","email.com","mail.com","wixpress.com","wix.com","godaddy.com"}

STATE_MAP = {
 'Alabama':'AL','Alaska':'AK','Arizona':'AZ','Arkansas':'AR','California':'CA','Colorado':'CO','Connecticut':'CT',
 'Delaware':'DE','Florida':'FL','Georgia':'GA','Hawaii':'HI','Idaho':'ID','Illinois':'IL','Indiana':'IN','Iowa':'IA',
 'Kansas':'KS','Kentucky':'KY','Louisiana':'LA','Maine':'ME','Maryland':'MD','Massachusetts':'MA','Michigan':'MI',
 'Minnesota':'MN','Mississippi':'MS','Missouri':'MO','Montana':'MT','Nebraska':'NE','Nevada':'NV','New Hampshire':'NH',
 'New Jersey':'NJ','New Mexico':'NM','New York':'NY','North Carolina':'NC','North Dakota':'ND','Ohio':'OH','Oklahoma':'OK',
 'Oregon':'OR','Pennsylvania':'PA','Rhode Island':'RI','South Carolina':'SC','South Dakota':'SD','Tennessee':'TN','Texas':'TX',
 'Utah':'UT','Vermont':'VT','Virginia':'VA','Washington':'WA','West Virginia':'WV','Wisconsin':'WI','Wyoming':'WY'
}

def e164(phone):
    if not phone: return None
    digits = re.sub(r'\D', '', phone)
    if len(digits) == 10: return '+1' + digits
    if len(digits) == 11 and digits.startswith('1'): return '+' + digits
    return None

def clean_email(email):
    if not email: return None
    email = email.strip().lower()
    if email in JUNK_EMAILS: return None
    m = re.match(r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$", email)
    if not m: return None
    domain = email.split('@')[-1]
    if domain in BAD_EMAIL_DOMAINS: return None
    return email

def state2abbr(s):
    if not s: return None
    s = s.strip()
    return STATE_MAP.get(s, (s[:2].upper() if len(s)>=2 else s))

def psql(sql):
    cmd = ["psql","-h",os.getenv("POSTGRES_HOST","localhost"),"-p",os.getenv("POSTGRES_PORT","5432"),
           "-U",os.getenv("POSTGRES_USER","directus"),"-d",os.getenv("POSTGRES_DB","eta07_prod"),
           "-v","ON_ERROR_STOP=1","-c",sql]
    env = os.environ.copy()
    env["PGPASSWORD"] = os.getenv("POSTGRES_PASSWORD","")
    subprocess.check_call(cmd, env=env)

def insert_staging_row(raw, service_guess, srcfile):
    payload = json.dumps(raw).replace("'","''")
    svc = service_guess.replace("'","''")
    src = srcfile.replace("'","''")
    sql = f"INSERT INTO staging.upload_raw(service_guess, source_file, raw_row) VALUES ('{svc}', '{src}', '{payload}')"
    psql(sql)

if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="Load CSV into staging.upload_raw")
    ap.add_argument("csv_path")
    ap.add_argument("--service", default="")
    args = ap.parse_args()
    src = args.csv_path
    service = args.service

    with open(src, newline='', encoding="utf-8", errors="ignore") as f:
        reader = csv.DictReader(f)
        for row in reader:
            if "Phone" in row:
                row["Phone_E164"] = e164(row.get("Phone"))
            if "State" in row:
                row["State"] = state2abbr(row.get("State"))
            if "Email" in row:
                row["Email"] = clean_email(row.get("Email"))
            insert_staging_row(row, service, os.path.basename(src))
    print("Loaded into staging.upload_raw")
