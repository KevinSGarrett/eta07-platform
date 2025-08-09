
#!/usr/bin/env python3
# FastAPI enqueue endpoint for enrichment (simplified stub)
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import os

app = FastAPI()
class Payload(BaseModel):
    lead_ids: list[str]
    dry_run: bool = False

@app.post("/api/enrich/queue")
def queue(payload: Payload):
    if not payload.lead_ids:
        raise HTTPException(400, "No leads selected")
    # TODO: validate quota, cooldown, write to enrich.enrichment_requests
    return {"queued": len(payload.lead_ids), "dry_run": payload.dry_run}
