import os, subprocess

def psql_file(path):
    cmd = [
        "psql",
        "-h", os.getenv("POSTGRES_HOST", "localhost"),
        "-p", os.getenv("POSTGRES_PORT", "5432"),
        "-U", os.getenv("POSTGRES_USER", "directus"),
        "-d", os.getenv("POSTGRES_DB", "eta07_prod"),
        "-v", "ON_ERROR_STOP=1",
        "-f", path
    ]
    env = os.environ.copy()
    env["PGPASSWORD"] = os.getenv("POSTGRES_PASSWORD", "")
    subprocess.check_call(cmd, env=env)

if __name__ == "__main__":
    schema_path = os.path.join(os.path.dirname(__file__), "..", "db", "schema.sql")
    print(f"Applying schema from {schema_path}")
    psql_file(schema_path)
    print("Done.")
