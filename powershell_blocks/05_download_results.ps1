# =============================================================================
# BLOCK 5 — DOWNLOAD CIF AND NPZ FILES
# Tool: BoltzProt-1 (Boltz antibody design via boltz-api CLI)
#
# What it does:
#   Polls the BoltzProt-1 API every 30 seconds until the design job is
#   complete, then downloads every output file for every design into a
#   structured folder tree under $root\$runName\results\.
#
#   Per-design folder layout:
#     results\<design_id>\files\
#       <design_id>_predicted.cif   — full complex structure (target + antibody)
#       pae.npz                     — PAE (Predicted Aligned Error) matrix
#       metrics.json                — iptm, binding_confidence, ipae, etc.
#       metadata.json               — designed sequences (ABH1 heavy, ABL1 light)
#
# Why:
#   Both the CIF and the PAE NPZ are required by Block 7 (lasv_ipsae.py) to
#   compute the ipSAE score. The metadata.json holds the actual antibody
#   sequences that go into the final CSV.
#
#   --download-mode everything  ensures CIF, NPZ, metrics AND metadata are all
#   pulled down in one step. Leave the PowerShell window open for the full
#   job duration — large jobs (100+ designs) can take 10–30 minutes.
#
# Note:
#   If the window closes or the download is interrupted, simply re-run this
#   block. The CLI resumes from where it left off.
# =============================================================================

$jobId  = Get-Content "$work\job_id.txt"
$runDir = "$root\$runName"

boltz-api download-results `
    --id               $jobId `
    --name             $runName `
    --root-dir         $root `
    --download-mode    everything `
    --poll-interval-seconds 30

# Verify the download
"cif files : " + (Get-ChildItem "$runDir\results" -Recurse -Filter "*_predicted.cif").Count
"npz files : " + (Get-ChildItem "$runDir\results" -Recurse -Filter "pae.npz").Count

# Success looks like:
#   cif files : 100
#   npz files : 100
# Both counts should match num_proteins. If they differ, rerun this block.
