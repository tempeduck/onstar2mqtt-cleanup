# Agent Guidance

Read the detailed project context in **`CLAUDE.md`**, especially its
**`## Active Handoff`** section for current state. `README.md` holds the full
operational detail. Codex loads the shared private guidance in
`~/.codex/AGENTS.md` automatically.

## Conventions for any agent working here
- **Secrets**: never hardcode. Creds come from env, `~/projects/secrets.env`,
  or HA `secrets.yaml` via SSH. NEVER write a secret value into `CLAUDE.md`/`AGENTS.md` —
  both are in git (public repo).
- **Live cron**: `mqtt_cleanup.sh` runs Sundays 03:00. Don't break/relocate it without
  updating the crontab.
- **Dry-run first**: show a plan before changing the script or live MQTT/HA state.
- **Handoff**: before finishing, update `## Active Handoff` in `CLAUDE.md`, tagged with the
  date + your model name, e.g. `[2026-06-20 (Antigravity)]`.
- **Artifacts**: write any analysis into this repo, never only to a tool-private
  directory.
