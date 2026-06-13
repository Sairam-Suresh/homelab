#!/usr/bin/env bash
set -euo pipefail

USER_HOME="$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)"
POLICY_DIR="$USER_HOME/.homelab/selinux"

mkdir -p "$POLICY_DIR"

sudo ausearch -m AVC,USER_AVC -ts recent > ./avcfile

podman inspect homelab_coder_1 > ./selinux/coder.json
podman inspect homelab_database_1 > ./selinux/database.json
podman inspect homelab_tailscale_1 > ./selinux/tailscale.json

sudo udica -j ./selinux/database.json homelab_database_container --append-rules avcfile
sudo udica -j ./selinux/coder.json homelab_coder_container --append-rules avcfile
sudo udica -j ./selinux/tailscale.json homelab_tailscale_container --append-rules avcfile

rm ./selinux/coder.json 
rm ./selinux/database.json 
rm ./selinux/tailscale.json 

sudo mv -f ./homelab_coder_container.cil "$POLICY_DIR/"
sudo mv -f ./homelab_database_container.cil "$POLICY_DIR/"
sudo mv -f ./homelab_tailscale_container.cil "$POLICY_DIR/"

sudo semodule -i "$POLICY_DIR/homelab_coder_container.cil" /usr/share/udica/templates/{base_container.cil,net_container.cil}
sudo semodule -i "$POLICY_DIR/homelab_database_container.cil" /usr/share/udica/templates/{base_container.cil,net_container.cil}
sudo semodule -i "$POLICY_DIR/homelab_tailscale_container.cil" /usr/share/udica/templates/{base_container.cil,net_container.cil}