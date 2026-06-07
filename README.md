# onstar2mqtt-cleanup

Automated cleanup of deprecated onstar2mqtt API v2 sensors after migration to API v3.

## Background

The [BigThunderSR/homeassistant-addons-onstar2mqtt](https://github.com/BigThunderSR/onstar2mqtt)
add-on migrated to OnStar API v3, which deprecated certain MQTT sensor topics. This script
removes stale retained MQTT messages from the broker and their corresponding orphaned entities
from Home Assistant.

## Dependencies

- `mosquitto-clients` — for `mosquitto_pub` / `mosquitto_sub`
- `jq` — JSON parsing
- `curl` — Home Assistant REST API calls
- SSH access to `root@10.10.1.20` (optional — used to read MQTT credentials from HA secrets.yaml
  if `MQTT_PASS` is not exported)

Install on Ubuntu/Debian:
```bash
sudo apt-get install -y mosquitto-clients jq curl
```

## Configuration

The script reads credentials from two sources (in order of preference):

1. Exported environment variables: `MQTT_USER`, `MQTT_PASS`, `HA_TOKEN`
2. `~/projects/unifi-scripts/secrets.env` (sourced automatically)
3. Falls back to reading `/homeassistant/secrets.yaml` on the HA host via SSH for `MQTT_PASS`

## Usage

### Manual run
```bash
~/projects/onstar2mqtt-cleanup/mqtt_cleanup.sh
```

Logs are written to `~/projects/onstar2mqtt-cleanup/cleanup.log`.

### What it does

1. Subscribes to `homeassistant/sensor/3GNAXLEG4SL315002/#` with `--retained-only` (5-second window)
2. Parses each config payload with `jq` — flags slugs whose `value_template` references
   `value_json.other` or whose HA entity state is `unavailable`/`unknown` with no retained state topic
3. For each stale slug:
   - Publishes an empty retained message to clear the MQTT config and state topics
   - Calls `DELETE /api/config/entity_registry/<entity_id>` on the HA REST API
   - Logs the action with a timestamp
4. If nothing is stale, logs: `No stale sensors found.` and exits 0

The script is **idempotent** — re-running when nothing is stale is safe and produces a clean log entry.

## Cron schedule

Runs every **Sunday at 03:00 AM** on the Ubuntu VM (10.10.1.19):

```
0 3 * * 0 ~/projects/onstar2mqtt-cleanup/mqtt_cleanup.sh >> ~/projects/onstar2mqtt-cleanup/cleanup.log 2>&1
```

Log location: `~/projects/onstar2mqtt-cleanup/cleanup.log`

## Vehicle

- **Make/Model**: 2025 Chevrolet Equinox
- **VIN**: 3GNAXLEG4SL315002
- **MQTT prefix**: `homeassistant/sensor/3GNAXLEG4SL315002`
