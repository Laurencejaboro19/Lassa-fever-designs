# =============================================================================
# BLOCK 2 — AUTH / LOGIN
# Tool: BoltzProt-1 (Boltz antibody design via boltz-api CLI)
#
# What it does:
#   Signs this PowerShell session into your Boltz (BoltzProt-1) account using
#   the official boltz-api CLI. The login flow opens a browser tab for OAuth
#   approval and stores a session token locally.
#
# Why:
#   The Boltz API requires an authenticated session before you can submit
#   design jobs (Block 4) or download results (Block 5). The token expires
#   after some time, so if any later block returns an "auth_required" error,
#   simply re-run this block and then re-run the failed block.
#
# When to re-run:
#   - At the start of every new PowerShell window.
#   - Any time a block prints "auth_required" or "unauthenticated".
# =============================================================================

boltz-api auth login

# Success looks like:
#   The CLI completes the OAuth flow (may open a browser window to approve)
#   and returns to the prompt without printing an error.
