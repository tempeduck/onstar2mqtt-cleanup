# AGENTS.md — context pointer for non-Claude agents (Gemini / Antigravity / etc.)

This project is worked on by BOTH Claude Code and Google Antigravity (Gemini).
The canonical context lives in **`CLAUDE.md`** in this same directory — read it in full,
especially the **`## Active Handoff`** section at the bottom for current state. `README.md`
holds the full operational detail.

Also read the global context at **`~/.claude/CLAUDE.md`** (network IPs, shared secrets
path, SSH, and the dual-model workflow rules).

## Conventions for any AI working here
- **Secrets**: never hardcode. Creds come from env, `~/projects/unifi-scripts/secrets.env`,
  or HA `secrets.yaml` via SSH. NEVER write a secret value into `CLAUDE.md`/`AGENTS.md` —
  both are in git (public repo).
- **Live cron**: `mqtt_cleanup.sh` runs Sundays 03:00. Don't break/relocate it without
  updating the crontab.
- **Dry-run first**: show a plan before changing the script or live MQTT/HA state.
- **Handoff**: before finishing, update `## Active Handoff` in `CLAUDE.md`, tagged with the
  date + your model name, e.g. `[2026-06-20 (Antigravity)]`.
- **Artifacts**: write any analysis INTO this repo, NOT to `~/.gemini/.../brain/` —
  Claude Code cannot see that directory.
