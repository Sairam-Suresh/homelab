#!/usr/bin/env bash
set -euo pipefail

# Regenerate and reload SELinux policies using additional allow rules from an AVC log file.
# Usage:
#   ./selinux/update_policies.sh [options] [output-avcfile]
#
# Options:
#   -c, --container NAME   Update a specific container policy (coder|database|tailscale).
#                          May be specified multiple times.
#   -h, --help             Show this help message.

usage() {
  cat <<EOF
Usage: $0 [options] [output-avcfile]

Regenerate and reload SELinux policies using allow rules generated from AVC logs.

Options:
  -c, --container NAME   Update only selected container(s): coder, database, tailscale.
                         May be supplied multiple times.
  -h, --help             Show this help message.

Arguments:
  output-avcfile         Optional path for AVC output.
                         Defaults to: <script-dir>/avcfile.log
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SELECTED_CONTAINERS=()
AVC_FILE_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--container)
      if [[ $# -lt 2 ]]; then
        echo "Error: missing value for $1" >&2
        usage
        exit 1
      fi

      case "$2" in
        coder|database|tailscale)
          if [[ " ${SELECTED_CONTAINERS[*]} " != *" $2 "* ]]; then
            SELECTED_CONTAINERS+=("$2")
          fi
          ;;
        all)
          SELECTED_CONTAINERS=("coder" "database" "tailscale")
          ;;
        *)
          echo "Error: invalid container '$2'. Expected coder, database, tailscale, or all." >&2
          usage
          exit 1
          ;;
      esac
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -* )
      echo "Error: unknown option: $1" >&2
      usage
      exit 1
      ;;
    *)
      if [[ -n "$AVC_FILE_ARG" ]]; then
        echo "Error: only one output-avcfile argument is allowed" >&2
        usage
        exit 1
      fi
      AVC_FILE_ARG="$1"
      shift
      ;;
  esac
done

if [[ ${#SELECTED_CONTAINERS[@]} -eq 0 ]]; then
  SELECTED_CONTAINERS=("database" "coder" "tailscale")
fi

is_selected_container() {
  local target="$1"
  local container
  for container in "${SELECTED_CONTAINERS[@]}"; do
    if [[ "$container" == "$target" ]]; then
      return 0
    fi
  done
  return 1
}

AVC_FILE="${AVC_FILE_ARG:-$SCRIPT_DIR/avcfile.log}"
AUTO_GENERATED_AVC=false
if [[ -z "$AVC_FILE_ARG" ]]; then
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

if ! command -v podman >/dev/null 2>&1; then
  echo "Error: podman is not installed or not in PATH" >&2
  exit 1
fi

echo "Generating AVC file from all available audit logs: $AVC_FILE"
mkdir -p "$(dirname "$AVC_FILE")"

# Collect all currently available AVC records from audit logs.
if ! sudo ausearch --input-logs -m AVC,USER_AVC,SELINUX_ERR,USER_SELINUX_ERR > "$AVC_FILE"; then
  echo "Error: failed to collect AVC events with ausearch" >&2
  exit 1
fi

if [[ ! -s "$AVC_FILE" ]]; then
  echo "Error: no AVC denials found. Exercise the containers to trigger denials, then rerun." >&2
  exit 1
fi

POLICIES=(
  "database:homelab_database_1:database.json:homelab_database_container"
  "coder:homelab_coder_1:coder.json:homelab_coder_container"
  "tailscale:homelab_tailscale_1:tailscale.json:homelab_tailscale_container"
)

GENERATED_JSON_FILES=()

echo "Selected containers: ${SELECTED_CONTAINERS[*]}"

for entry in "${POLICIES[@]}"; do
  IFS=":" read -r container_key container_name json_file module_name <<< "$entry"

  if ! is_selected_container "$container_key"; then
    continue
  fi

  json_path="$SCRIPT_DIR/$json_file"

  echo "Inspecting container: $container_name"
  if ! podman inspect "$container_name" > "$json_path"; then
    echo "Error: failed to inspect container: $container_name" >&2
    exit 1
  fi
  GENERATED_JSON_FILES+=("$json_path")

  echo "Updating policy: $module_name"
  sudo udica -j "$json_path" -a "$AVC_FILE" "$module_name"
  sudo mv -f "$module_name.cil" "$POLICY_DIR/"
  sudo semodule -i "$POLICY_DIR/$module_name.cil" /usr/share/udica/templates/{base_container.cil,net_container.cil}
done

# Cleanup generated files that are not needed after policy load.
if [[ "$AUTO_GENERATED_AVC" == "true" && -f "$AVC_FILE" ]]; then
  rm -f "$AVC_FILE"
fi

for json_file in "${GENERATED_JSON_FILES[@]}"; do
  rm -f "$json_file"
done

echo "Policy update complete."