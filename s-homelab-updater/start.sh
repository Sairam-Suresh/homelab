#!/usr/bin/env bash
set -euo pipefail

# Run relative to this script so docker-compose.yml is always found over SSH.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

LOGFILE="/tmp/homelab-updater.log"

echo "[$(date --iso-8601=seconds)] start.sh invoked (cwd=$PWD)" >> "$LOGFILE"

# Try to find podman-compose in PATH or common install locations
PODMAN_COMPOSE_BIN=""
PODMAN_COMPOSE_BIN="$(command -v podman-compose || true)"
if [ -z "$PODMAN_COMPOSE_BIN" ]; then
	for p in /usr/local/bin /usr/bin /bin /home/$USER/.local/bin; do
		if [ -x "$p/podman-compose" ]; then
			PODMAN_COMPOSE_BIN="$p/podman-compose"
			break
		fi
	done
fi

if [ -z "$PODMAN_COMPOSE_BIN" ]; then
	echo "[$(date --iso-8601=seconds)] podman-compose not found in PATH or common locations" | tee -a "$LOGFILE" >&2
	exit 1
fi

echo "[$(date --iso-8601=seconds)] Using $PODMAN_COMPOSE_BIN" >> "$LOGFILE"

echo "[$(date --iso-8601=seconds)] podman-compose down --remove-orphans" >> "$LOGFILE"
# run down but continue if it fails (log failure)
if ! "$PODMAN_COMPOSE_BIN" down --remove-orphans >>"$LOGFILE" 2>&1; then
	echo "[$(date --iso-8601=seconds)] podman-compose down failed (continuing)" >> "$LOGFILE"
fi

echo "[$(date --iso-8601=seconds)] podman-compose up -d" >> "$LOGFILE"
if ! "$PODMAN_COMPOSE_BIN" up -d >>"$LOGFILE" 2>&1; then
	echo "[$(date --iso-8601=seconds)] podman-compose up failed" | tee -a "$LOGFILE" >&2
	echo "See $LOGFILE for details" >&2
	exit 1
fi

# Remove tar if present (no error if absent)
rm -f /home/sairamsuresh/github-project-deployer.tar.gz
echo "[$(date --iso-8601=seconds)] finished successfully" >> "$LOGFILE"