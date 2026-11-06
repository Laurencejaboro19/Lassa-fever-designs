# =============================================================================
# BLOCK 4 — SUBMIT THE DESIGN JOB  ⚠️  THIS SPENDS CREDIT
# Tool: BoltzProt-1 (Boltz antibody design via boltz-api CLI)
#
# What it does:
#   Sends lasv_design.json to the BoltzProt-1 API, which starts the antibody
#   design run. The returned job ID is printed and saved to job_id.txt so
#   Block 5 can find it automatically.
#
# Why:
#   The idempotency key (timestamp-based) prevents an accidental double-submit
#   if you re-run this block within a short window — Boltz will return the
#   existing job rather than starting a new one and charging twice.
#   Use a NEW idempotency key (or just re-run this block fresh) whenever you
#   change the payload in Block 3.
#
# Cost:
#   num_proteins × $0.20  (100 designs = ~$20).
#   Lower num_proteins in Block 3 before running this if you want a test run.
#   Minimum is 10 designs.
# =============================================================================

# Requires: Block 1 variables ($work) in scope and Block 3 JSON file on disk.

$key = "lasv-BE-" + (Get-Date -Format "yyyyMMdd-HHmmss")

$out = boltz-api --format raw protein:design start `
    --input "@json://$($work.Replace('\','/'))/lasv_design.json" `
    --idempotency-key $key

$jobId = ($out | ConvertFrom-Json).id
$jobId | Set-Content "$work\job_id.txt"
Write-Host "JOB ID: $jobId"

# Success looks like:
#   JOB ID: prot_des_xxxxxxxxxxxxxxxxxxxx
# If the ID is blank, read the error above it:
#   - "auth_required"  → rerun Block 2 then retry here.
#   - Payload error    → check Block 3 output and fix the JSON.
