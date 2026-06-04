#!/usr/bin/env bash
# ============================================================================
# SessionStart hook — install the xceptor plugin IN-SESSION.
#
# Why a hook (not the setup script): the setup script can't see the
# environment's env vars at build time, and the native settings.json
# bootstrap doesn't auto-install in cloud sessions (both verified
# 2026-06-04). A SessionStart hook runs inside the session, where GH_TOKEN
# IS available — the one place the working `claude plugin install` can run
# automatically every session.
#
# Requires (set on the cloud environment): GH_TOKEN = GitHub token with
# read access to xceptor-engineering/ai-pdlc.
#
# Contract: ALL diagnostics go to ~/xceptor-install.log; ONLY the
# reloadSkills JSON is written to stdout, so Claude Code re-scans skills and
# the plugin is usable in the same session.
# ============================================================================

{
  set -uo pipefail
  if [ -z "${GH_TOKEN:-}" ]; then
    echo "$(date -u +%FT%TZ) GH_TOKEN unset — skipping xceptor install (expected for local sessions)"
  elif claude plugin list 2>/dev/null | grep -q "xceptor@xceptor-pdlc"; then
    echo "$(date -u +%FT%TZ) xceptor already installed — nothing to do"
  else
    MP="$HOME/marketplaces/ai-pdlc"
    if [ ! -d "$MP/.claude-plugin" ]; then
      rm -rf "$MP"; mkdir -p "$HOME/marketplaces"
      git clone --depth 1 "https://x-access-token:${GH_TOKEN}@github.com/xceptor-engineering/ai-pdlc.git" "$MP" \
        && git -C "$MP" remote set-url origin https://github.com/xceptor-engineering/ai-pdlc.git
    fi
    claude plugin marketplace add "$MP" || echo "WARN: marketplace add failed"
    claude plugin install xceptor@xceptor-pdlc || echo "WARN: plugin install failed"
    claude plugin list || true
  fi
} >> "$HOME/xceptor-install.log" 2>&1

# Tell Claude Code to re-scan skills so xceptor is active THIS session.
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","reloadSkills":true}}\n'
