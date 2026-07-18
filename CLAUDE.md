# onstar2mqtt-cleanup — Claude Code Context

> Shared infra facts, secrets policy, and working rules live in `~/.claude/CLAUDE.md`.
> Full operational detail (deps, exact behavior, install) is in `README.md` — read it first.

## Project Summary

Idempotent cleanup script that removes stale **retained** onstar2mqtt MQTT topics and their
orphaned Home Assistant entities left behind by the OnStar API v2 → v3 migration (BigThunderSR
onstar2mqtt add-on). Targets the 2025 Chevrolet Equinox under MQTT prefix
`homeassistant/sensor/3GNAXLEG4SL315002`.

## Environment

- **Host**: Ubuntu VM at 10.10.1.19 — `~/projects/onstar2mqtt-cleanup/`
- **Live cron**: Sundays 03:00 (`0 3 * * 0 mqtt_cleanup.sh >> cleanup.log 2>&1`). Don't
  break or relocate the script without updating that crontab entry.
- **MQTT broker / HA**: 10.10.1.20 (Mosquitto + HA REST API)
- **Secrets**: env `MQTT_USER`/`MQTT_PASS`/`HA_TOKEN` → else sourced from
  `~/projects/secrets.env` → else `MQTT_PASS` read from HA
  `/homeassistant/secrets.yaml` via SSH (`root@10.10.1.20`). Never hardcode.
- **GitHub**: https://github.com/robertscheib/onstar2mqtt-cleanup (public)

## Files

- `mqtt_cleanup.sh` — the cleanup script (idempotent; logs to `cleanup.log`)
- `retained_dump.txt` — gitignored scratch dump of retained topics
- `cleanup.log` — run log

## Rules / Do not

- Public repo — never commit a secret value (creds come from env / secrets.env / HA SSH).
- The script is idempotent; "No stale sensors found." is the normal no-op result.
- Don't widen the MQTT subscribe beyond the vehicle prefix without dry-running — clearing
  retained topics is destructive to that device's HA entities.
- Before changes, re-read `README.md` for current behavior.

## Active Handoff

- [2026-06-22 (Antigravity)]: Updated `mqtt_cleanup.sh` and docs to point to the correct secrets file location (`~/projects/secrets.env` instead of `~/projects/unifi-scripts/secrets.env`).
- [2026-06-20 (Claude Code)]: Added CLAUDE.md + standard AGENTS.md so this project matches
  the rest of the tree (it previously had only a README). No code/cron changes.
- [2026-06-07]: Built + deployed (idempotent sweep, Sunday 03:00 cron, public GitHub repo).
  History detail lives in the `unifi-scripts` handoff journal under that date.
