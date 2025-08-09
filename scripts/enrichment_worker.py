
#!/usr/bin/env python3
# Async worker (skeleton)
import os, asyncio, asyncpg, httpx, json

PDL_API_KEY = os.getenv("PDL_API_KEY","")
DB_URL = os.getenv("DATABASE_URL","postgresql://directus:pass@localhost:5432/eta07_prod")

async def run_once():
    # TODO: fetch queued requests, call PDL, store results, merge according to rules
    print("Worker tick...")

async def main():
    while True:
        await run_once()
        await asyncio.sleep(5)

if __name__ == "__main__":
    asyncio.run(main())
