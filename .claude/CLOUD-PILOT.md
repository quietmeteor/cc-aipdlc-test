# AI-PDLC Cloud Session Pilot

Goal: validate that the `xceptor` plugin (skills + hooks) from our private
marketplace (`xceptor-engineering/ai-pdlc`) loads and functions in a
**Claude Code cloud session** (Anthropic-managed VM), reproducing the
GitHub-integrated workflow from Chris's demo.

## One-time environment setup (claude.ai/code)

1. **Setup script** — paste the contents of `.claude/cloud-setup.sh` into the
   environment's *Setup script* field (installs gh, .NET SDK 8, Azure CLI).
2. **Environment variables** — set on the environment (never in the repo):
   - `AZURE_DEVOPS_EXT_PAT` — ADO PAT (work-item read scope is enough for the
     state-guard hook)
   - `AI_PDLC_OTLP_ENDPOINT` — Grafana OTLP endpoint (optional; usage hook
     queues locally and continues if unreachable)
3. **Network access** — `Custom` (include Trusted defaults) + allow:
   `packages.microsoft.com`, `aka.ms`, `azurecliprod.blob.core.windows.net`,
   `dev.azure.com`, and the Grafana host if used.
4. **GitHub App access — the critical unknown.** The Claude GitHub App must be
   granted access to **`xceptor-engineering/ai-pdlc`** (the marketplace repo),
   not just this repo. Private-marketplace auth in cloud sessions is an open
   gap (anthropics/claude-code#9756), so this step may or may not be
   sufficient — that's exactly what this pilot measures.

## What's wired in this repo

- `.claude/settings.json` — declares the `xceptor-pdlc` marketplace and
  enables `xceptor@xceptor-pdlc`. Cloud sessions install repo-declared
  plugins at session start. **Must be committed to the branch the cloud
  session checks out** (merge to the default branch so every session gets it).

## Verification checklist (run in a cloud session)

| # | Check | How | Pass looks like |
|---|---|---|---|
| 1 | Plugin installed | Ask: "list available /xceptor: skills" or run `/xceptor:help-xceptor` | Skills enumerate; help renders |
| 2 | Hooks fire | Edit any file, then ask Claude to `git commit` | usage-hook lines in transcript; pre-commit hook runs (no-ops here: no `.sln`) |
| 3 | az auth works | Ask Claude to run `az boards work-item show --id <known-id>` | Work item JSON returns (PAT + egress OK) |
| 4 | State guard | Run a guarded skill (e.g. `/xceptor:engineering`) against a known story | Guard fetches the story state instead of erroring |
| 5 | Telemetry | Check Grafana for the session's usage events | Events arrive (or hook logs queued-locally fallback) |

## If the private marketplace fetch fails (check #1)

Fallback (documented to work — repo contents are "part of the clone"):
vendor the plugin into this repo — copy `plugins/xceptor/skills|agents|commands`
into `.claude/` and move `hooks/hooks.json` entries into `.claude/settings.json`
(with `scripts/dist/` copied alongside). Clunky but unblocks the pilot;
revisit when anthropics/claude-code#9756 lands.

## Notes for the brainstorm

- Cloud VM: Ubuntu 24.04, 4 vCPU / 16 GB / 30 GB, **no devcontainer support**;
  customization = setup script + env vars + network allowlist only.
- Hooks run wherever the Claude process runs; cloud sessions set
  `CLAUDE_CODE_REMOTE` if we ever want cloud-specific hook behavior.
- This repo is Python, so the .NET hooks no-op by design (they require a
  `.sln`). The real C# validation needs a connector repo mirrored to GitHub.
