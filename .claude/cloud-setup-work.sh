#!/usr/bin/env bash
# ============================================================================
# Cloud environment setup — WORK edition (xceptor-engineering), v3
#
# Paste into: claude.ai/code -> environment -> Setup script.
# Runs at environment BUILD time, before Claude Code launches.
#
# IMPORTANT (verified 2026-06-04): the setup script does NOT receive the
# environment's configured Environment variables — they are injected only
# into the interactive session shell. So the setup script CANNOT use a token
# to clone private repos. The xceptor plugin install therefore does NOT live
# here anymore. The plugin is installed by the native marketplace bootstrap
# in .claude/settings.json, which reads GH_TOKEN in-session at startup.
#
# This script's job is just the TOOLCHAIN (needs no secrets, cacheable):
#   gh, .NET SDK 8 (ai-pdlc dotnet hooks), Azure CLI + azure-devops ext.
#
# Set on the ENVIRONMENT (not here):
#   GH_TOKEN              GitHub token the plugin auto-update reads to fetch
#                         the private xceptor-engineering/ai-pdlc marketplace
#   AZURE_DEVOPS_EXT_PAT  ADO token for the userstory-state-guard hook
# Network: Custom + dev.azure.com, packages.microsoft.com, aka.ms,
#   azurecliprod.blob.core.windows.net
# ============================================================================

set -uo pipefail
exec > >(tee -a "$HOME/cloud-setup.log") 2>&1
echo "===== cloud-setup-work v3 (toolchain only) — build started ====="
export DEBIAN_FRONTEND=noninteractive
if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi

echo "=== [1/3] apt + gh + .NET SDK 8 ==="
$SUDO apt-get update -y || echo "WARN: apt update failed"
command -v gh >/dev/null 2>&1 || $SUDO apt-get install -y gh || echo "WARN: gh install failed"
command -v dotnet >/dev/null 2>&1 || $SUDO apt-get install -y dotnet-sdk-8.0 || echo "WARN: dotnet install failed"

echo "=== [2/3] Azure CLI ==="
command -v az >/dev/null 2>&1 || curl -sL https://aka.ms/InstallAzureCLIDeb | $SUDO bash || echo "WARN: az install failed"

echo "=== [3/3] azure-devops extension ==="
if command -v az >/dev/null 2>&1; then
  az extension show --name azure-devops >/dev/null 2>&1 || az extension add --name azure-devops || echo "WARN: az-devops ext failed"
fi

echo "===== Setup complete — tool versions ====="
node --version 2>/dev/null || echo "node: missing"
command -v claude >/dev/null 2>&1 && claude --version || echo "claude CLI: missing"
gh --version 2>/dev/null | head -1 || echo "gh: missing"
dotnet --version 2>/dev/null || echo "dotnet: missing"
az version 2>/dev/null | head -1 || echo "az: missing"
echo "NOTE: xceptor plugin is installed by native bootstrap (settings.json + GH_TOKEN), not here. Full log: ~/cloud-setup.log"
