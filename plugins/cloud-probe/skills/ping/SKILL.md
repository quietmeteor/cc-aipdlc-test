---
name: ping
description: Diagnostic probe that proves the cloud-probe plugin installed from the cc-test marketplace. Use when the user runs /cloud-probe:ping or asks to verify plugin installation in this session.
---

# Cloud Probe — Plugin Install Diagnostic

You have been invoked, which by itself proves that:
- the `cc-test` marketplace declared in `.claude/settings.json` was fetched, and
- the `cloud-probe` plugin was installed and its skills registered.

Perform these steps and report results in a single compact summary:

1. Start the reply with this exact line:
   `✅ CLOUD-PROBE LOADED — marketplace plugin installation WORKS in this session.`

2. Report the execution environment by running in Bash:
   `echo "remote=${CLAUDE_CODE_REMOTE:-unset} user=$(whoami) os=$(uname -a | cut -c1-60)"`

3. Report whether the OTHER plugin from settings.json also loaded: check
   whether any `xceptor` skills (e.g. `/xceptor:help-xceptor`,
   `/xceptor:feature-status`) are available to you right now.
   - If yes: print `✅ xceptor@xceptor-pdlc ALSO loaded — private marketplace works.`
   - If no: print `❌ xceptor@xceptor-pdlc NOT loaded — cc-test (same-repo marketplace) installed but the private org marketplace did not. Conclusion: the blocker is access to xceptor-engineering/ai-pdlc, not the plugin mechanism.`

4. List any plugin-install warnings or errors you can find:
   `ls -la ~/.claude/plugins/ 2>/dev/null; cat ~/.claude/logs/* 2>/dev/null | grep -i -m5 -E "marketplace|plugin" || echo "no plugin logs found"`

Keep the whole report under 15 lines. Do not take any other action.
