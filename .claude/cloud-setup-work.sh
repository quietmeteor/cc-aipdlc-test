#!/usr/bin/env bash
# ============================================================================
# Cloud environment setup — WORK edition (xceptor-engineering)
#
# Paste into: claude.ai/code -> environment -> Setup script (work account).
# Runs inside Anthropic's cloud VM (Ubuntu 24.04) — NOT on your machine.
# Your work machine's SSO (gh/az login) does NOT propagate here:
#   - GitHub: the VM has a proxy credential scoped to the session repo.
#     Step 3 TESTS whether it also covers other org repos (ai-pdlc). If yes,
#     no PAT is needed; if no, it falls back to GH_PAT.
#   - Azure DevOps: no SSO in the VM. Set AZURE_DEVOPS_EXT_PAT as an
#     environment variable (work-item read scope) for the state-guard hook.
#
# Environment variables (set on the environment, never here):
#   GH_PAT                  fine-grained PAT, read-only Contents on
#                           xceptor-engineering/ai-pdlc (only if step 3
#                           reports the proxy credential is insufficient)
#   AZURE_DEVOPS_EXT_PAT    ADO PAT for az boards (state-guard hook)
#   AI_PDLC_OTLP_ENDPOINT   optional Grafana OTLP target for usage telemetry
#
# Network access: Custom (incl. Trusted defaults) + dev.azure.com,
#   packages.microsoft.com, aka.ms, azurecliprod.blob.core.windows.net
#   (+ Grafana host if used).
# ============================================================================

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi

echo "=== [1/4] Base tools (gh, .NET SDK 8) ==="
$SUDO apt-get update -y
command -v gh >/dev/null 2>&1 || $SUDO apt-get install -y gh
# Needed by ai-pdlc pre-commit/post-edit hooks on C# repos (no-op without .sln)
command -v dotnet >/dev/null 2>&1 || $SUDO apt-get install -y dotnet-sdk-8.0

echo "=== [2/4] Azure CLI + azure-devops extension ==="
if ! command -v az >/dev/null 2>&1; then
  curl -sL https://aka.ms/InstallAzureCLIDeb | $SUDO bash
fi
az extension show --name azure-devops >/dev/null 2>&1 || az extension add --name azure-devops

echo "=== [3/4] Fetch ai-pdlc marketplace (proxy credential first, PAT fallback) ==="
MP_DIR="$HOME/marketplaces/ai-pdlc"
rm -rf "$MP_DIR"
if git clone --depth 1 https://github.com/xceptor-engineering/ai-pdlc.git "$MP_DIR" 2>/dev/null; then
  echo "RESULT: proxy credential covers org repos — NO GitHub PAT needed"
elif [ -n "${GH_PAT:-}" ]; then
  git clone --depth 1 "https://x-access-token:${GH_PAT}@github.com/xceptor-engineering/ai-pdlc.git" "$MP_DIR"
  git -C "$MP_DIR" remote set-url origin https://github.com/xceptor-engineering/ai-pdlc.git  # scrub PAT from .git/config
  echo "RESULT: proxy credential insufficient — cloned via GH_PAT fallback"
else
  echo "RESULT: cannot clone ai-pdlc (proxy denied, GH_PAT unset) — xceptor plugin will be UNAVAILABLE"
fi

echo "=== [4/4] Install xceptor plugin from local marketplace clone ==="
# Cloud sessions don't bootstrap settings-declared marketplaces (verified
# 2026-06-04), so install explicitly; env cache persists this for every session.
if [ -d "$MP_DIR" ] && command -v claude >/dev/null 2>&1; then
  claude plugin marketplace add "$MP_DIR" || true
  claude plugin install xceptor@xceptor-pdlc || true
  claude plugin list || true
else
  echo "Skipping plugin install (no marketplace clone or no claude CLI at setup time)"
fi

echo "=== Setup complete — tool versions ==="
node --version
gh --version | head -1
dotnet --version 2>/dev/null || echo "dotnet: not installed"
az version 2>/dev/null | head -3 || echo "az: not installed"
