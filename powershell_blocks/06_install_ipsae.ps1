# =============================================================================
# BLOCK 6 — INSTALL ipSAE PACKAGE AND COPY SCORER SCRIPT
# Tool: BoltzProt-1 / ipSAE (Python scoring package)
#
# What it does:
#   1. Installs the `ipsae` Python package and numpy via pip.
#   2. Verifies the import resolves to the installed package (not a stray file).
#   3. Copies lasv_ipsae.py from Downloads into the working folder so Block 7
#      can find it.
#
# Why:
#   The ipSAE score measures the quality of the predicted interface between the
#   designed antibody and the target epitope chains (B and E on 8EJE). It is
#   derived from the PAE matrix (pae.npz) and the structure (CIF), and is a
#   more sensitive measure of binding confidence than iptm alone.
#
#   ⚠️  IMPORTANT: Do NOT leave an old file called ipsae.py in the working
#   folder ($HOME\lassa-fever-designs\). Python puts the script's directory
#   first on sys.path, so a stray ipsae.py there shadows the installed package
#   and causes this error when scoring:
#       "could not convert string to float: '--epitope'"
#   If you see that error, delete or rename the stray file and rerun Block 6.
#
# Requires:
#   lasv_ipsae.py saved in $HOME\Downloads\ (included in the repo under
#   powershell_blocks\lasv_ipsae.py — copy it there first).
# =============================================================================

pip install ipsae numpy --quiet
python -c "import ipsae; print('ipsae OK:', hasattr(ipsae, 'calculate_ipsae'))"

# Copy the scorer script from Downloads (or from the repo folder next to this file)
$src = "$HOME\Downloads\lasv_ipsae.py"
if (-not (Test-Path $src)) {
    # Fallback: look next to this script
    $src = Join-Path $PSScriptRoot "lasv_ipsae.py"
}
$dst = "$work\lasv_ipsae.py"

if (Test-Path $src) {
    Copy-Item $src $dst -Force
    Write-Host "lasv_ipsae.py copied to: $dst"
} else {
    Write-Warning "lasv_ipsae.py not found. Copy it into $work manually before running Block 7."
}
Test-Path $dst

# Success looks like:
#   ipsae OK: True
#   lasv_ipsae.py copied to: C:\Users\<you>\lassa-fever-designs\lasv_ipsae.py
#   True
# If the last line is False, copy lasv_ipsae.py into the working folder by hand.
