#!/bin/sh

# 1. Install nftables into the Alpine container
apk add --no-cache nftables > /dev/null

# 2. Define the nftables ruleset natively
cat << 'EOF' > /etc/nftables.conf
#!/usr/sbin/nft -f

# Clear any existing rules in the namespace
flush ruleset

table inet filter {
    chain output {
        # Hook into outbound traffic. Default policy is to accept.
        type filter hook output priority 0; policy accept;

        # 1. Allow established and related connections
        ct state established,related accept

        # 2. Allow traffic to the Tailscale subnet
        ip daddr 100.64.0.0/10 accept

        # 3. Allow local loopback traffic
        ip daddr 127.0.0.0/8 accept

        # 4. Block access to private LAN ranges
        # nftables natively supports sets {}, making this a clean one-liner
        ip daddr { 192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12 } drop
    }
}
EOF

# 3. Apply the ruleset to the kernel
nft -f /etc/nftables.conf

# 4. Suspend the script so the container (and the shared network namespace) doesn't exit
echo "nftables firewall rules applied successfully."
exec sleep infinity