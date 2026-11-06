# =============================================================================
# BLOCK 7 — SCORE ipSAE, CALCULATE ALL METRICS, AND SAVE CSV
# Tool: BoltzProt-1 / ipSAE (Python scoring package)
#
# What it does:
#   Runs lasv_ipsae.py over every downloaded design. For each design it:
#     1. Loads the CIF structure and PAE NPZ from the download folder.
#     2. Calls ipsae.calculate_ipsae() to compute interface PAE scores.
#     3. Reads Boltz metrics (iptm, binding_confidence, etc.) from metrics.json.
#     4. Reads the designed sequences (ABH1 heavy, ABL1 light) from metadata.json.
#     5. Assigns a verdict: GOOD / BORDERLINE / WEAK / OFF_TARGET / BAD / ERROR.
#   Saves the full ranked results to ipsae_multichain_ranking.csv and copies a
#   clean copy to Downloads as LASV_BE_designs_ranked.csv.
#
# Why:
#   ipSAE is the gold-standard interface score for Boltz outputs. It captures
#   whether the antibody is genuinely predicted to contact the intended epitope
#   (chains B and E on 8EJE) rather than drifting to background chains (A, C, D, F).
#   The verdict column lets you filter to GOOD or BORDERLINE candidates immediately.
#
# Output CSV columns:
#   rank, result_id, verdict, verdict_reason,
#   ipsae_epitope  — on-target ipSAE (chains B+E, higher = better)
#   ipsae_offtarget — off-target drift to chains A/C/D/F (lower = better)
#   on_target, ipsae_max, ipsae_pair,
#   ipsae_A, ipsae_B, ipsae_C, ipsae_D, ipsae_E, ipsae_F  — per-chain scores
#   d0chn, n0chn, target_chains, binder_chains,
#   iptm, min_interaction_pae, binding_confidence, structure_confidence, status,
#   seq_ABH1   — designed heavy chain sequence
#   seq_ABL1   — designed light chain sequence
#
# Chain configuration for 8EJE:
#   --epitope  B,E      GP1 (chain B) + GP2 (chain E) — the two hotspot chains
#   --decoys   A,C,D,F  all other chains (structural context, should NOT score high)
#   --binders  ABH1,ABL1  heavy + light chain outputs from BoltzProt-1
# =============================================================================

Set-Location $work
$runDir = "$root\$runName"

python lasv_ipsae.py `
    --run-dir      $runDir `
    --epitope      B,E `
    --decoys       A,C,D,F `
    --binders      ABH1,ABL1 `
    --pae-cutoff   15 `
    --dist-cutoff  10 `
    --out-csv      "$runDir\ipsae_multichain_ranking.csv"

# Preview top 5 results in the terminal
Import-Csv "$runDir\ipsae_multichain_ranking.csv" |
    Select-Object -First 5 rank,result_id,verdict,ipsae_epitope,ipsae_offtarget,iptm,min_interaction_pae |
    Format-Table -AutoSize

# Copy finished CSV to Downloads for easy access
Copy-Item "$runDir\ipsae_multichain_ranking.csv" `
    "$HOME\Downloads\LASV_BE_designs_ranked.csv" -Force
Write-Host "Saved to: $HOME\Downloads\LASV_BE_designs_ranked.csv"

# Success looks like:
#   scoring 100 designs | pae_cutoff=15 dist_cutoff=10 | workers=N
#   25/100 scored ... 100/100 scored
#   DONE -> ...\ipsae_multichain_ranking.csv
#   verdicts: GOOD=X, BORDERLINE=Y, WEAK=Z, OFF_TARGET=W, BAD=V
#   TOP 10 by on-target ipSAE ...
#   (table of top 5 rows)
#   Saved to: C:\Users\<you>\Downloads\LASV_BE_designs_ranked.csv
