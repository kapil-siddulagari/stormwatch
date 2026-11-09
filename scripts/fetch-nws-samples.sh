#!/usr/bin/env bash
# Fetches the current NWS active alerts once and saves three sample payloads
# for ingestion-service tests:
#   alert-new.json            a new alert (messageType = Alert) with geometry
#   alert-update.json         an Update or Cancel, which references earlier alerts
#   alert-null-geometry.json  a new alert without geometry (zone-based)
# Each file keeps the real response shape: a FeatureCollection with one feature.
# Alerts for the given state (default FL) are preferred; otherwise any state is used.
#
# Usage: scripts/fetch-nws-samples.sh [STATE]
set -euo pipefail

STATE="${1:-FL}"
UA="StormWatch/0.1 (github.com/kapil-siddulagari/stormwatch)"
API="https://api.weather.gov/alerts/active"
OUT_DIR="services/ingestion-service/src/test/resources/nws"

command -v jq >/dev/null || { echo "jq is required: brew install jq" >&2; exit 1; }
cd "$(git rev-parse --show-toplevel)"
mkdir -p "$OUT_DIR"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

echo "Fetching active alerts nationwide..."
curl -sSf -A "$UA" -H "Accept: application/geo+json" "$API" -o "$tmp"
echo "Active alerts: $(jq '.features | length' "$tmp")"

# save FILE CONDITION
# CONDITION is a jq expression evaluated against each alert feature.
save() {
  local file="$1" condition="$2"
  jq --arg state "$STATE" "
    [.features[] | select($condition)] as \$matches
    | ([\$matches[] | select(any(.properties.geocode.UGC[]?; startswith(\$state)))] + \$matches)
    | first // empty
    | {type: \"FeatureCollection\", features: [.]}
  " "$tmp" > "$OUT_DIR/$file"

  if [[ -s "$OUT_DIR/$file" ]]; then
    jq -r --arg file "$file" \
      '.features[0].properties | "saved \($file): \(.messageType) | \(.event) | \(.areaDesc[0:60])"' \
      "$OUT_DIR/$file"
  else
    rm -f "$OUT_DIR/$file"
    echo "no match for $file right now; try again later" >&2
  fi
}

save alert-new.json           '.properties.messageType == "Alert" and .geometry != null'
save alert-update.json        '.properties.messageType == "Update" or .properties.messageType == "Cancel"'
save alert-null-geometry.json '.geometry == null and .properties.messageType == "Alert"'
