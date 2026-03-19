#!/usr/bin/env bash
set -euo pipefail

# Run from script directory so podman-compose finds the compose file
cd "$(dirname "$0")"

if ! command -v podman-compose >/dev/null 2>&1; then
	echo "podman-compose not found in PATH" >&2
	exit 1
fi

echo "Stopping any existing podman-compose services (if present)..."
# run down but don't fail if nothing to stop
podman-compose down || true

echo "Starting podman-compose services..."
podman-compose up -d

# Remove tar if present (no error if absent)
rm -f /home/sairamsuresh/github-project-deployer.tar.gz