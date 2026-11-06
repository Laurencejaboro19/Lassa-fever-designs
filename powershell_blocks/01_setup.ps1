# =============================================================================
# BLOCK 1 — SETUP
# Tool: BoltzProt-1 (Boltz antibody design via boltz-api CLI)
#
# What it does:
#   Creates the working folder and sets the path variables that every later
#   block depends on. Run this first, in the same PowerShell window you will
#   use for the rest of the pipeline.
#
# Why:
#   Keeping all paths in one place means you only need to edit $cif here if
#   your structure file has a different name or lives in a different folder.
#   All other blocks inherit $work, $cif, $runName, and $root automatically
#   as long as you run them in the same session.
#
# Edit before running:
#   $cif     — full path to your 8EJE CIF file (must be in Downloads or
#              wherever you saved it; default shown below).
#   $runName — change this to start a fresh run without overwriting results.
# =============================================================================

$work    = "$HOME\lassa-fever-designs"
$cif     = "$HOME\Downloads\8EJE_boltz_ABCDEF.cif"
$runName = "LASV-BE-run1"
$root    = "$work\boltz-experiments"

New-Item -ItemType Directory -Force $work | Out-Null
New-Item -ItemType Directory -Force $root | Out-Null
Set-Location $work

Write-Host "work folder : $work"
Write-Host "cif found   : $(Test-Path $cif)"

# Success looks like:
#   work folder : C:\Users\<you>\lassa-fever-designs
#   cif found   : True
# If cif found says False, fix the $cif path above before going on.
