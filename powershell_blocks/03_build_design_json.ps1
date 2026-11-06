# =============================================================================
# BLOCK 3 — BUILD THE DESIGN INPUT JSON
# Tool: BoltzProt-1 (Boltz antibody design via boltz-api CLI)
#
# What it does:
#   Reads your 8EJE CIF file, base64-encodes it, and writes lasv_design.json —
#   the complete input payload for a BoltzProt-1 antibody design job.
#
# Why:
#   BoltzProt-1 needs the target structure embedded in the JSON as a base64
#   string, with explicit chain selections and epitope residue indices so the
#   model knows where to dock the antibody. The hotspot / epitope configuration
#   below encodes the two key Lassa GPC neutralising surfaces:
#
#     Chain B (GP1 head domain) residues 2–12   → 0-indexed as 1..11
#     Chain E (GP2 fusion domain) residues 132–147 → 0-indexed as 131..146
#
#   Chains A, C, D, F are included as structural context but carry no epitope
#   tag, so BoltzProt-1 treats them as decoy / background chains.
#
#   binder_specification "boltz_antibody" instructs BoltzProt-1 to output a
#   two-chain antibody: ABH1 (heavy chain) and ABL1 (light chain) — matching
#   the seq_ABH1 / seq_ABL1 column names in the existing 8k design CSV.
#
# Edit before running:
#   num_proteins — number of antibody designs to generate ($0.20 each).
#                  Minimum is 10. Default here is 100 (~$20).
#                  Lower to 10 for a cheap test run first.
# =============================================================================

$b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($cif))

$sel = [ordered]@{}
foreach ($c in "A","B","C","D","E","F") {
    $sel[$c] = [ordered]@{ chain_type = "polymer"; crop_residues = "all" }
}

# --- HOTSPOT / EPITOPE CONFIGURATION ---
# GP1 chain B, residues 2-12 (Boltz uses 0-based indexing, so residue 2 = index 1)
$sel["B"]["epitope_residues"] = @(1..11)

# GP2 chain E, residues 132-147 (0-indexed: 131..146)
$sel["E"]["epitope_residues"] = @(131..146)
# ----------------------------------------

$req = [ordered]@{
    num_proteins = 100
    target = [ordered]@{
        type      = "structure_template"
        structure = [ordered]@{
            type       = "base64"
            media_type = "chemical/x-cif"
            data       = $b64
        }
        chain_selection = $sel
    }
    binder_specification = [ordered]@{
        type   = "boltz_curated"
        binder = "boltz_antibody"   # outputs ABH1 (heavy) + ABL1 (light)
    }
}

# Write without BOM so the CLI reads it cleanly
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText(
    "$work\lasv_design.json",
    ($req | ConvertTo-Json -Depth 12),
    $utf8NoBom
)

"{0:N0} bytes written to lasv_design.json" -f (Get-Item "$work\lasv_design.json").Length
"B epitope (0-indexed): " + ($sel["B"]["epitope_residues"] -join ",")
"E epitope (0-indexed): " + ($sel["E"]["epitope_residues"] -join ",")

# Success looks like:
#   NNN,NNN bytes written to lasv_design.json  (hundreds of KB — CIF is embedded)
#   B epitope (0-indexed): 1,2,3,4,5,6,7,8,9,10,11
#   E epitope (0-indexed): 131,132,133,...,146
# Nothing has been sent to Boltz yet. No credit is spent here.
