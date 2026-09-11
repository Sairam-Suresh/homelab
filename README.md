# My Homelab

This repository contains configurations and deployment files for services hosted across my homelab nodes.

## Deployment Architecture

Automated continuous deployment is handled by the **Homelab Updater Service** (`ghcr.io/sairam-suresh/homelab-update-service:latest`), running inside the `control-plane` stack behind Caddy and connected to Tailscale.

When changes are pushed to `main`, GitHub Actions:
1. Connects to the homelab Tailscale network.
2. Dynamically detects which service directories were changed (inspecting folders containing a `deploy.yaml`).
3. Dispatches a webhook request (`POST /api/v1/deploy`) to the updater daemon with the repository URL, commit SHA, and service relative path.
4. The updater daemon cryptographically verifies the commit signature against `/etc/homelab-updater/allowed_signers`.
5. The updater synchronizes files using `rsync` over SSH to the target device defined in `devices.yaml` and executes the service's `bootstrap.sh` or `start.sh`.

### Directory Structure

- `control-plane/`: Core infrastructure services (Tailscale, Caddy reverse proxy, Step-CA, AdGuard Home, VoidAuth, Homelab Updater).
  - `deploy.yaml`: Deployment manifest for the control plane.
- `s-coder/`: Coder development environment and PostgreSQL database.
  - `deploy.yaml`: Deployment manifest targeting `tower`.
- `s-workspace-gateway/`: Tailscale gateway and DNS-over-SOCKS proxy for developer workspaces.
  - `deploy.yaml`: Deployment manifest targeting `local`.