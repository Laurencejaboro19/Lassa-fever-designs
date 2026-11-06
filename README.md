# Lassa Fever Antibody Design — BoltzProt-1 Pipeline

**Tool:** [BoltzProt-1](https://boltz.bio) via the `boltz-api` CLI  
**Target:** Lassa virus glycoprotein complex — PDB [8EJE](https://www.rcsb.org/structure/8EJE) (chains A–F)  
**Project:** Protein Design for Africa (PDFA) × Edo State Ministry of Health  
**Designer:** Laurence Jaboro (PDFA) · laurencejaboro858@gmail.com

---

## What this repo contains

Seven PowerShell blocks that form a complete end-to-end pipeline for designing and scoring de novo antibodies against the Lassa virus GPC trimer using **BoltzProt-1**, plus the Python scoring script `lasv_ipsae.py`.

```
powershell_blocks/
  01_setup.ps1              — Set working folder and path variables
  02_auth_login.ps1         — Authenticate to the Boltz API
  03_build_design_json.ps1  — Encode 8EJE + hotspots → lasv_design.json
  04_submit_job.ps1         — Submit the BoltzProt-1 design job (spends credit)
  05_download_results.ps1   — Download CIF structures and PAE NPZ files
  06_install_ipsae.ps1      — Install ipSAE Python package + copy scorer
  07_score_and_save_csv.ps1 — Score all designs, calculate metrics, save CSV
  lasv_ipsae.py             — Multichain ipSAE scorer (Python 3)
```

---

## Target and hotspot configuration

| Property | Value |
|---|---|
| Structure | PDB 8EJE (`8EJE_boltz_ABCDEF.cif`) |
| Target chains | A, B, C, D, E, F |
| **Epitope chain B** (GP1 head) | Residues 2–12 → Boltz 0-indexed: `1..11` |
| **Epitope chain E** (GP2 fusion) | Residues 132–147 → Boltz 0-indexed: `131..146` |
| Decoy / context chains | A, C, D, F |
| Binder type | `boltz_antibody` → outputs **ABH1** (heavy) + **ABL1** (light) |
| ipSAE on-target | `--epitope B,E` |
| ipSAE off-target | `--decoys A,C,D,F` |
| PAE cutoff | 15 |

---

## How to run

Open **PowerShell** and paste each block in order. All blocks must run in the **same PowerShell window** (they share the `$work`, `$cif`, `$runName`, and `$root` variables set in Block 1).

### Before you start

1. Download the **8EJE CIF** file from [RCSB](https://www.rcsb.org/structure/8EJE) and save it to `Downloads\8EJE_boltz_ABCDEF.cif`.
2. Install the `boltz-api` CLI if you haven't already.
3. Copy `lasv_ipsae.py` (from this repo) into your `Downloads` folder.

### Block order

| # | File | Cost |
|---|---|---|
| 1 | `01_setup.ps1` | Free |
| 2 | `02_auth_login.ps1` | Free |
| 3 | `03_build_design_json.ps1` | Free |
| 4 | `04_submit_job.ps1` | **~$20 for 100 designs** |
| 5 | `05_download_results.ps1` | Free |
| 6 | `06_install_ipsae.ps1` | Free |
| 7 | `07_score_and_save_csv.ps1` | Free |

---

## Output

Block 7 produces:

- `boltz-experiments\LASV-BE-run1\ipsae_multichain_ranking.csv` — full ranked table
- `Downloads\LASV_BE_designs_ranked.csv` — copy for easy access

**Key columns:**

| Column | Meaning |
|---|---|
| `rank` | 1 = best on-target ipSAE |
| `verdict` | GOOD / BORDERLINE / WEAK / OFF_TARGET / BAD / ERROR |
| `ipsae_epitope` | ipSAE score on chains B+E (higher = better, ≥0.5 is GOOD) |
| `ipsae_offtarget` | ipSAE score on decoy chains A/C/D/F (lower = better) |
| `iptm` | Interface predicted TM score from BoltzProt-1 |
| `min_interaction_pae` | Minimum interface PAE (lower = better) |
| `binding_confidence` | BoltzProt-1 binding confidence score |
| `seq_ABH1` | Designed heavy chain sequence |
| `seq_ABL1` | Designed light chain sequence |

---

## About the ipSAE scorer

`lasv_ipsae.py` runs `ipsae.calculate_ipsae()` over the full 6-chain complex
and reports per-chain interface scores in both directions (target→binder and
binder→target). It detects off-target drift (antibody binding the wrong chain)
and classifies each design with a verdict. Scoring uses the downloaded CIF and
PAE NPZ files from Block 5.

**Verdict thresholds** (tune in `lasv_ipsae.py` if needed):

| Verdict | Condition |
|---|---|
| GOOD | ipsae_epitope ≥ 0.50 and min_ipae ≤ 10.0 |
| BORDERLINE | ipsae_epitope ≥ 0.30 |
| WEAK | ipsae_epitope ≥ 0.05 |
| OFF_TARGET | ipsae_offtarget > ipsae_epitope + 0.02 |
| BAD | ipsae_epitope < 0.05 (no real interface) |

---

## Notes

- Block 4 is the only block that spends Boltz credit. Set `num_proteins` in Block 3 to 10 for a cheap test run first.  
- Do **not** leave a file called `ipsae.py` in your working folder — it shadows the installed package and breaks scoring.
- The 8k design CSV produced from previous runs lives separately and is not committed here (it contains full antibody sequences).
