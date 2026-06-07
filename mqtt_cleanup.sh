#!/usr/bin/env bash
set -euo pipefail

SECRETS_FILE="$HOME/projects/unifi-scripts/secrets.env"
VIN="3GNAXLEG4SL315002"
MQTT_HOST="10.10.1.20"
LOG_FILE="$HOME/projects/onstar2mqtt-cleanup/cleanup.log"
HA_BASE="http://10.10.1.20:8123"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

# Dependency check
for dep in mosquitto_pub mosquitto_sub jq curl; do
    if ! command -v "$dep" &>/dev/null; then
        echo "ERROR: missing dependency: $dep" >&2
        exit 1
    fi
done

# Load credentials
if [[ ! -f "$SECRETS_FILE" ]]; then
    echo "ERROR: secrets file not found: $SECRETS_FILE" >&2
    exit 1
fi
# Extract MQTT and HA credentials — keys live in HA secrets.yaml, not secrets.env,
# so we read them directly from the YAML file via SSH if not already exported.
MQTT_USER="${MQTT_USER:-mosquitto}"
MQTT_PASS="${MQTT_PASS:-}"
HA_TOKEN="${HA_TOKEN:-}"

# Source secrets.env first; fall back to reading HA secrets.yaml via SSH
source "$SECRETS_FILE" || true

if [[ -z "$MQTT_PASS" ]]; then
    MQTT_PASS=$(ssh -o StrictHostKeyChecking=no -o BatchMode=yes root@10.10.1.20 \
        "grep -A1 'mqttbroker_username' /homeassistant/secrets.yaml | grep 'mqttbroker_userpassword' | awk -F'\"' '{print \$2}'" 2>/dev/null || true)
fi

if [[ -z "$HA_TOKEN" || -z "$MQTT_PASS" ]]; then
    echo "ERROR: MQTT_PASS or HA_TOKEN not available" >&2
    exit 1
fi

log "=== onstar2mqtt cleanup run started ==="

# Step 1: Collect all retained config topics
TMPDIR_CLEAN=$(mktemp -d)
trap 'rm -rf "$TMPDIR_CLEAN"' EXIT

RETAINED="$TMPDIR_CLEAN/retained.txt"
mosquitto_sub -h "$MQTT_HOST" -u "$MQTT_USER" -P "$MQTT_PASS" \
    -t "homeassistant/sensor/${VIN}/#" \
    --retained-only -W 5 \
    -F "%t\t%p" 2>/dev/null > "$RETAINED" || true

config_count=$(grep -c '/config' "$RETAINED" 2>/dev/null || echo 0)
log "Retained config topics found: $config_count"

# Step 2: Identify stale slugs
stale_slugs=()
while IFS=$'\t' read -r topic payload; do
    [[ "$topic" != */config ]] && continue
    slug=$(echo "$topic" | awk -F'/' '{print $(NF-1)}')
    val_template=$(echo "$payload" | jq -r '.value_template // empty' 2>/dev/null)
    state_topic=$(echo "$payload" | jq -r '.state_topic // empty' 2>/dev/null)

    is_stale=false

    # Check if value_template references deprecated value_json.other
    if echo "$val_template" | grep -qE 'value_json\.other(\b|_)'; then
        is_stale=true
        log "STALE (deprecated template): slug=$slug topic=$topic"
    fi

    # Also cross-check: if HA state for this slug is unavailable/unknown
    # AND the slug was already cleared from the broker (no retained state)
    if [[ "$is_stale" == false ]]; then
        entity_id="sensor.2025_chevrolet_equinox_${slug}"
        # Normalize dashes to underscores for entity_id lookup
        entity_id=$(echo "$entity_id" | tr '-' '_')
        ha_state=$(curl -sf -H "Authorization: Bearer $HA_TOKEN" \
            "${HA_BASE}/api/states/${entity_id}" 2>/dev/null | jq -r '.state // empty' || true)
        if [[ "$ha_state" == "unavailable" || "$ha_state" == "unknown" ]]; then
            # Only flag as stale if the state topic also has no retained payload
            state_retained=$(grep -F "$state_topic" "$RETAINED" | head -1 || true)
            if [[ -z "$state_retained" ]]; then
                is_stale=true
                log "STALE (unavailable + no retained state): slug=$slug entity=$entity_id"
            fi
        fi
    fi

    if [[ "$is_stale" == true ]]; then
        stale_slugs+=("$slug")
    fi
done < "$RETAINED"

if [[ ${#stale_slugs[@]} -eq 0 ]]; then
    log "No stale sensors found."
    exit 0
fi

log "Stale slugs to purge: ${stale_slugs[*]}"

# Step 3: Purge each stale slug
for slug in "${stale_slugs[@]}"; do
    config_topic="homeassistant/sensor/${VIN}/${slug}/config"
    state_topic="homeassistant/sensor/${VIN}/${slug}/state"

    # Clear retained config topic
    mosquitto_pub -h "$MQTT_HOST" -u "$MQTT_USER" -P "$MQTT_PASS" \
        -t "$config_topic" -n -r
    log "Purged MQTT retained: $config_topic"

    # Clear retained state topic
    mosquitto_pub -h "$MQTT_HOST" -u "$MQTT_USER" -P "$MQTT_PASS" \
        -t "$state_topic" -n -r
    log "Purged MQTT retained: $state_topic"

    # Remove entity from HA (entity_id derived from slug)
    entity_id="sensor.2025_chevrolet_equinox_${slug}"
    entity_id=$(echo "$entity_id" | tr '-' '_')

    ha_resp=$(curl -sf -w "\n%{http_code}" -X DELETE \
        -H "Authorization: Bearer $HA_TOKEN" \
        "${HA_BASE}/api/config/entity_registry/${entity_id}" 2>/dev/null || echo "000")
    http_code=$(echo "$ha_resp" | tail -1)

    if [[ "$http_code" == "200" ]]; then
        log "Deleted HA entity: $entity_id"
    elif [[ "$http_code" == "404" ]]; then
        log "HA entity already gone (404): $entity_id"
    else
        log "WARNING: HA entity delete returned HTTP $http_code for $entity_id"
    fi
done

log "=== Cleanup complete. Slugs purged: ${stale_slugs[*]} ==="
