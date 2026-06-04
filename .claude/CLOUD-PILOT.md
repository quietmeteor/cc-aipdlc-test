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

- `.claude/settings.json` — declares the `xceptor-pdlc` + `cc-test`
  marketplaces and enables both plugins. Kept for local sessions and for
  when the cloud bootstrap gap (below) is fixed upstream.
- `.claude/cloud-setup.sh` §5 — **the mechanism that actually works in
  cloud**: explicit `claude plugin marketplace add` + `claude plugin install`
  at environment build; private ai-pdlc cloned via `GH_PAT` env var and
  registered as a local-path marketplace.

## Verified findings (2026-06-04)

1. **Cloud sessions do NOT bootstrap repo-declared `extraKnownMarketplaces`**
   from `.claude/settings.json` — `~/.claude/plugins/` is never created,
   public or private, App access or not. Contradicts the docs' "installed at
   session start". Report upstream (related: anthropics/claude-code#9756).
2. **The `claude plugin` CLI works inside the cloud VM** (non-interactive,
   no trust prompt, user scope) — verified via `/cloud-probe:ping`:
   `remote=true user=root`, plugin loaded and skill invocable.
3. **Persistence rule**: mid-session installs die with the session. Installs
   in the **setup script** land in the cached environment snapshot and are
   present in every fresh session.
4. Local control test passes for both marketplaces (incl. private ai-pdlc)
   — the failure is cloud-bootstrap-specific, not a config problem.
5. **(2026-06-04, work account, session on `ai-agent-service`)** The cloud
   VM's GitHub proxy credential is **strictly session-repo-scoped**: cloning
   a sibling org repo (`xceptor-engineering/ai-pdlc`) is DENIED even with
   the Claude GitHub App installed org-wide. Cross-repo private marketplace
   fetch therefore always needs an explicit token (`GH_PAT`, fine-grained,
   read-only Contents) — by design, not a bug. Work-machine SSO never
   propagates to the VM.
6. The `claude` CLI (2.1.162) IS available at env-build time — setup-script
   plugin installs are viable. Toolchain confirmed in cloud: Node 22,
   .NET SDK 8.0.127, gh 2.45, az 2.87.
7. **Cache gotcha**: changing environment *variables* may not invalidate the
   cached snapshot — touch the setup script (e.g. bump a version comment)
   to force a rebuild after adding `GH_PAT`.

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
