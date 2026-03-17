#!/usr/bin/env bash
set -euo pipefail

# Regenerate and reload SELinux policies using additional allow rules from an AVC log file.
# Usage:
#   ./selinux/update_policies.sh [output-avcfile]
#
# This script expects these files to already exist (from generate_policies.sh):
#   selinux/coder.json
#   selinux/database.json
#   selinux/tailscale.json

if [[ $# -gt 1 ]]; then
  echo "Usage: $0 [output-avcfile]" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AVC_FILE="${1:-$SCRIPT_DIR/avcfile.log}"
AUTO_GENERATED_AVC=false
if [[ $# -eq 0 ]]; then
  AUTO_GENERATED_AVC=true
fi
USER_HOME="$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)"
POLICY_DIR="$USER_HOME/.homelab/selinux"

mkdir -p "$POLICY_DIR"

if ! command -v udica >/dev/null 2>&1; then
  echo "Error: udica is not installed or not in PATH" >&2
  exit 1
fi

if ! command -v semodule >/dev/null 2>&1; then
  echo "Error: semodule is not installed or not in PATH" >&2
  exit 1
fi

if ! command -v ausearch >/dev/null 2>&1; then
  echo "Error: ausearch is not installed or not in PATH" >&2
  exit 1
fi

podman inspect homelab_coder_1 > ./selinux/coder.json
podman inspect homelab_database_1 > ./selinux/database.json
podman inspect homelab_tailscale_1 > ./selinux/tailscale.json

echo "Generating AVC file: $AVC_FILE"
mkdir -p "$(dirname "$AVC_FILE")"

# Pull recent AVC denials first; if empty, retry from boot to capture older denials.
if ! sudo ausearch -m AVC,USER_AVC -ts recent > "$AVC_FILE"; then
  echo "Error: failed to collect AVC events with ausearch" >&2
  exit 1
fi

if [[ ! -s "$AVC_FILE" ]]; then
  if ! sudo ausearch -m AVC,USER_AVC,SELINUX_ERR,USER_SELINUX_ERR -ts boot > "$AVC_FILE"; then
    echo "Error: failed to collect AVC events from boot with ausearch" >&2
    exit 1
  fi
fi

if [[ ! -s "$AVC_FILE" ]]; then
  echo "Error: no AVC denials found. Exercise the containers to trigger denials, then rerun." >&2
  exit 1
fi

POLICIES=(
  "database.json:homelab_database_container"
  "coder.json:homelab_coder_container"
  "tailscale.json:homelab_tailscale_container"
)

for entry in "${POLICIES[@]}"; do
  json_file="${entry%%:*}"
  module_name="${entry##*:}"
  json_path="$SCRIPT_DIR/$json_file"

  if [[ ! -f "$json_path" ]]; then
    echo "Error: Missing inspect JSON file: $json_path" >&2
    echo "Run ./selinux/generate_policies.sh first." >&2
    exit 1
  fi

  echo "Updating policy: $module_name"
  sudo udica -j "$json_path" -a "$AVC_FILE" "$module_name"
  sudo mv -f "$module_name.cil" "$POLICY_DIR/"
  sudo semodule -i "$POLICY_DIR/$module_name.cil" /usr/share/udica/templates/{base_container.cil,net_container.cil}
done

# Cleanup generated files that are not needed after policy load.
if [[ "$AUTO_GENERATED_AVC" == "true" && -f "$AVC_FILE" ]]; then
  rm -f "$AVC_FILE"
fi

rm ./selinux/coder.json 
rm ./selinux/database.json 
rm ./selinux/tailscale.json 

echo "Policy update complete."