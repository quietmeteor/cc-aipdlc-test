#!/usr/bin/env bash
# ============================================================================
# Cloud environment setup script for Claude Code on the web (Ubuntu 24.04 VM)
#
# This file is the VERSIONED COPY. To use it, paste its contents into:
#   claude.ai/code -> your environment -> Setup script
# The script runs once when the environment boots; output is cached (~7 days)
# and reused by subsequent sessions unless the script changes.
#
# --- Network access (environment setting) ---
# Set Network access to "Custom" (include Trusted defaults) and allow:
#   packages.microsoft.com, aka.ms, azurecliprod.blob.core.windows.net  -> Azure CLI install
#   dev.azure.com                                                       -> userstory-state-guard hook (az boards)
#   <your-grafana-otlp-host>                                            -> usage-hook telemetry push (optional)
# apt/Ubuntu, GitHub, npm/PyPI are already covered by the Trusted defaults.
#
# --- Environment variables (environment setting — NOT in this script) ---
#   AZURE_DEVOPS_EXT_PAT=<ADO personal access token>   # non-interactive auth for `az boards`
#   AI_PDLC_OTLP_ENDPOINT=<grafana otlp endpoint>      # optional usage telemetry target
# Never hardcode secrets in this file: it is committed to the repo.
# ============================================================================

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Setup may run as root (no sudo present) or as a user with sudo.
if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi

echo "=== [1/4] apt update ==="
$SUDO apt-get update -y

echo "=== [2/4] GitHub CLI (gh) — used by ai-pdlc GitHub skills ==="
command -v gh >/dev/null 2>&1 || $SUDO apt-get install -y gh

echo "=== [3/4] .NET SDK 8 — used by pre-commit-check / post-edit-check hooks on C# repos ==="
# The hooks no-op when the repo has no .sln, so this is inert for non-.NET repos.
# Trim this section if your pilot only targets non-C# repos and you want faster env builds.
command -v dotnet >/dev/null 2>&1 || $SUDO apt-get install -y dotnet-sdk-8.0

echo "=== [4/4] Azure CLI + azure-devops extension — used by userstory-state-guard hook ==="
if ! command -v az >/dev/null 2>&1; then
  curl -sL https://aka.ms/InstallAzureCLIDeb | $SUDO bash
fi
az extension show --name azure-devops >/dev/null 2>&1 || az extension add --name azure-devops

# Optional: pin default ADO org/project for az calls. The ai-pdlc plugin has its
# own Project Resolution contract, so leave this commented unless you want a
# hard default for the pilot:
# az devops configure --defaults organization=https://dev.azure.com/xceptor project="AI PDLC"

echo "=== [5/5] Claude Code plugins — explicit install ==="
# Cloud sessions do NOT bootstrap repo-declared extraKnownMarketplaces from
# .claude/settings.json (verified 2026-06-04: ~/.claude/plugins is never
# created in cloud VMs). Install explicitly here instead — this runs at
# environment build, so the cached snapshot gives every session the plugins
# pre-installed at user scope.
if command -v claude >/dev/null 2>&1; then
  # Public probe marketplace (diagnostic)
  claude plugin marketplace add quietmeteor/cc-test-marketplace || true
  claude plugin install cloud-probe@cc-test || true

  # Private ai-pdlc marketplace — needs GH_PAT env var (repo:read scope) set
  # on the cloud environment. Cloned manually because bootstrap/proxy creds
  # don't cover repos outside the session repo.
  if [ -n "${GH_PAT:-}" ]; then
    rm -rf "$HOME/marketplaces/ai-pdlc"
    git clone --depth 1 "https://x-access-token:${GH_PAT}@github.com/xceptor-engineering/ai-pdlc.git" "$HOME/marketplaces/ai-pdlc"
    git -C "$HOME/marketplaces/ai-pdlc" remote set-url origin "https://github.com/xceptor-engineering/ai-pdlc.git"  # scrub PAT from .git/config
    claude plugin marketplace add "$HOME/marketplaces/ai-pdlc" || true
    claude plugin install xceptor@xceptor-pdlc || true
  else
    echo "GH_PAT not set — skipping private xceptor-pdlc marketplace install"
  fi
  claude plugin list || true
else
  echo "claude CLI not found at setup time — install plugins in-session instead"
fi

echo "=== Setup complete — tool versions ==="
node --version
gh --version | head -1
dotnet --version 2>/dev/null || echo "dotnet: not installed"
az version 2>/dev/null | head -3 || echo "az: not installed"
