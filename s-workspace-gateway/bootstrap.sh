#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if ! command -v podman-compose >/dev/null 2>&1; then
	echo "podman-compose not found in PATH" >&2
	exit 1
fi

podman-compose down --remove-orphans || true
podman-compose up -d
