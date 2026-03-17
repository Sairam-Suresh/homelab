import os

a = "clean_homelab_adguard_conf clean_homelab_adguard_work clean_homelab_caddy_config clean_homelab_caddy_data clean_homelab_step_data clean_homelab_tailscale_data clean_homelab_ts_socket clean_homelab_voidauth_db"

a_l = a.split(" ")
for i in a_l:
    os.system(f"podman volume export -o ~/backups/{i}.tar {i}")
    os.system(f"sudo mv ~/backups/{i}.tar ~/media/usb/{i}.tar")
    print(f"Backed up volume: {i}")