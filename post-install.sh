#!/usr/bin/env bash
#
# Nessus Integration — post-install script
#
# Recreates the Latest Transform with proper permissions and clears the
# "Deferred installations" warning in Fleet.
#
# Requirements: curl, jq
#
# Usage:
#   ./post-install.sh
#   ./post-install.sh https://es:9200 https://kbn:5601 elastic:changeme

set -euo pipefail

ES="${1:-https://localhost:9200}"
KBN="${2:-https://localhost:5601}"
AUTH="${3:-elastic:changeme}"
TID="logs-nessus.nessus_vulnerability_latest-default-0.1.0"
DIR="$(cd "$(dirname "$0")" && pwd)"
JSON="$DIR/transform_create.json"

echo "=== Nessus post-install ==="
echo "ES:  $ES"
echo "KBN: $KBN"
echo ""

# ── 1. Recreate transform ────────────────────────────────────────────
echo "[1/3] Stopping & deleting existing transform..."
curl -sk -u "$AUTH" -X POST "$ES/_transform/$TID/_stop?force=true" -o /dev/null 2>/dev/null || true
curl -sk -u "$AUTH" -X DELETE "$ES/_transform/$TID" -o /dev/null 2>/dev/null || true

echo "[2/3] Creating transform..."
curl -sfk -u "$AUTH" -X PUT "$ES/_transform/$TID" \
  -H "Content-Type: application/json" -d @"$JSON"
echo ""
curl -sfk -u "$AUTH" -X POST "$ES/_transform/$TID/_start"
echo ""

# ── 2. Clear deferred flag ───────────────────────────────────────────
echo "[3/3] Clearing 'Deferred installations' flag..."
if command -v jq &>/dev/null; then
  INSTALLED=$(curl -sfk -u "$AUTH" -H "kbn-xsrf: true" \
    "$KBN/api/saved_objects/epm-packages/nessus" \
    | jq '.attributes.installed_es | map(if .type == "transform" then .deferred = false else . end)')
  curl -sfk -u "$AUTH" -X PUT "$KBN/api/saved_objects/epm-packages/nessus" \
    -H "kbn-xsrf: true" -H "Content-Type: application/json" \
    -d "{\"attributes\":{\"installed_es\":$INSTALLED}}" -o /dev/null
  echo "  Done."
else
  echo "  (skipped — install jq to clear the flag automatically)"
fi

echo ""
echo "=== Done. Transform is running. ==="
