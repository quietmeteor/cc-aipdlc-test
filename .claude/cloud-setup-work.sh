#!/usr/bin/env bash
# ============================================================================
# Cloud environment setup — WORK edition (xceptor-engineering), v2
#
# Paste into: claude.ai/code -> environment -> Setup script (work account).
# Runs inside Anthropic's cloud VM (Ubuntu 24.04) — NOT on your machine.
# Work-machine SSO (gh/az login) does NOT propagate here.
#
# v2 changes:
#   - All output tee'd to ~/cloud-setup.log (UI logs can't be expanded;
#     run `cat ~/cloud-setup.log` in any session for the full build log)
#   - No hard abort: each section warns and continues (v1's set -e could
#     kill the plugin install if an earlier apt/az step hiccuped)
#   - If the session repo IS the marketplace (ai-pdlc), it is copied from
#     the working tree — no network or auth needed at all
#
# Environment variables (set on the environment, never here):
#   GH_PAT                  fine-grained PAT, read-only Contents on
#                           xceptor-engineering/ai-pdlc — only needed if the
#                           log shows the proxy-credential clone was denied
#   AZURE_DEVOPS_EXT_PAT    ADO PAT for az boards (state-guard hook)
#   AI_PDLC_OTLP_ENDPOINT   optional Grafana OTLP target for usage telemetry
#
# Network access: Custom (incl. Trusted defaults) + dev.azure.com,
#   packages.microsoft.com, aka.ms, azurecliprod.blob.core.windows.net
# ============================================================================

set -uo pipefail
exec > >(tee -a "$HOME/cloud-setup.log") 2>&1
echo "===== cloud-setup-work v2 — build started ====="
export DEBIAN_FRONTEND=noninteractive
if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi

echo "=== [1/4] ai-pdlc marketplace + xceptor plugin (critical path, runs first) ==="
MP_DIR="$HOME/marketplaces/ai-pdlc"
rm -rf "$MP_DIR"; mkdir -p "$HOME/marketplaces"
if [ -f "./.claude-plugin/marketplace.json" ] && grep -q '"xceptor"' "./.claude-plugin/marketplace.json" 2>/dev/null; then
  cp -r "$(pwd)" "$MP_DIR"
  echo "RESULT: session repo IS the marketplace — copied from working tree (no auth needed)"
elif git clone --depth 1 https://github.com/xceptor-engineering/ai-pdlc.git "$MP_DIR" 2>/dev/null; then
  echo "RESULT: proxy credential covers org repos — NO GitHub PAT needed"
elif [ -n "${GH_PAT:-}" ] && git clone --depth 1 "https://x-access-token:${GH_PAT}@github.com/xceptor-engineering/ai-pdlc.git" "$MP_DIR"; then
  git -C "$MP_DIR" remote set-url origin https://github.com/xceptor-engineering/ai-pdlc.git  # scrub PAT
  echo "RESULT: proxy credential insufficient — cloned via GH_PAT fallback"
else
  echo "RESULT: WARN — cannot obtain ai-pdlc (working tree: no, proxy clone: denied, GH_PAT: ${GH_PAT:+set-but-failed}${GH_PAT:-unset}). xceptor plugin will be UNAVAILABLE."
fi

if [ -d "$MP_DIR" ]; then
  if command -v claude >/dev/null 2>&1; then
    claude plugin marketplace add "$MP_DIR" || echo "WARN: marketplace add failed"
    claude plugin install xceptor@xceptor-pdlc || echo "WARN: plugin install failed"
    claude plugin list || true
  else
    echo "WARN: claude CLI not on PATH at env-build time — plugin not installed. In-session fallback: claude plugin marketplace add ~/marketplaces/ai-pdlc && claude plugin install xceptor@xceptor-pdlc"
  fi
fi

echo "=== [2/4] apt update + gh + .NET SDK 8 ==="
$SUDO apt-get update -y || echo "WARN: apt update failed"
command -v gh >/dev/null 2>&1 || $SUDO apt-get install -y gh || echo "WARN: gh install failed"
# Needed by ai-pdlc pre-commit/post-edit hooks on C# repos (no-op without .sln)
command -v dotnet >/dev/null 2>&1 || $SUDO apt-get install -y dotnet-sdk-8.0 || echo "WARN: dotnet install failed"

echo "=== [3/4] Azure CLI ==="
if ! command -v az >/dev/null 2>&1; then
  curl -sL https://aka.ms/InstallAzureCLIDeb | $SUDO bash || echo "WARN: az install failed"
fi

echo "=== [4/4] azure-devops extension ==="
if command -v az >/dev/null 2>&1; then
  az extension show --name azure-devops >/dev/null 2>&1 || az extension add --name azure-devops || echo "WARN: azure-devops extension install failed"
fi

echo "===== Setup complete — tool versions ====="
node --version 2>/dev/null || echo "node: missing"
command -v claude >/dev/null 2>&1 && claude --version || echo "claude CLI: missing"
gh --version 2>/dev/null | head -1 || echo "gh: missing"
dotnet --version 2>/dev/null || echo "dotnet: missing"
az version 2>/dev/null | head -1 || echo "az: missing"
echo "Full log: ~/cloud-setup.log"
