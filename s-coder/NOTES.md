# Some rough notes I took
semanage port -a -t http_port_t -p udp 443

sudo iptables -D FORWARD -s 192.168.122.0/24 -d 192.168.88.0/24 -p udp --dport 41641 -j ACCEPT
sudo iptables -D FORWARD -s 192.168.122.0/24 -d 192.168.88.0/24 -j DROP
Use -I to insert at the top of the chain