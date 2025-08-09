
# Enrichment Flow

- User selects rows in Directus → clicks "Enrich with PDL (N/500)".
- API validates quotas + cooldown; enqueues requests.
- Worker calls PDL with priority: email > phone > name+address > name+company+city/state > name > address.
- Confidence ≥0.90 auto-merge; 0.75–0.89 review; <0.75 no merge.
- Email summary sent to requester + Super Admin.
