import os

a = "homelab_adguard_conf homelab_adguard_work homelab_caddy_config homelab_caddy_data homelab_step_data homelab_tailscale_data homelab_ts_socket homelab_voidauth_db"

a_l = a.split(" ")
for i in a_l:
    os.system(f"podman volume create {i}")
    os.system(f"podman volume import {i} /media/usb/clean_{i}.tar")
    # os.system(f"sudo mv ~/backups/{i}.tar ~/media/usb/{i}.tar")

    print(f"Restored volume: {i}")
