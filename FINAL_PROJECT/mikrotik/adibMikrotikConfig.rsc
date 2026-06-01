# 2026-06-01 09:48:31 by RouterOS 7.20.8
# system id = F0AQo+Sz5RK
#
/interface ethernet
set [ find default-name=ether1 ] disable-running-check=no
set [ find default-name=ether2 ] disable-running-check=no
set [ find default-name=ether3 ] disable-running-check=no
/port
set 0 name=serial0
/ip address
add address=11.22.33.2/30 comment="WAN 1-2 (IP Public)" interface=ether1 \
    network=11.22.33.0
add address=10.0.1.1/29 comment="PUBLIC SUBNET 2-6" interface=ether2 network=\
    10.0.1.0
add address=10.0.2.1/29 comment="PRIVATE SUBNET 2-6" interface=ether3 \
    network=10.0.2.0
/ip dhcp-client
add interface=ether1
/ip dns
set servers=8.8.8.8
/ip firewall filter
add action=accept chain=input comment="Accept established router traffic" \
    connection-state=established,related
add action=drop chain=input comment="Drop WAN Pings to Router" dst-limit=\
    1,5,src-and-dst-addresses/1m in-interface=ether1 protocol=icmp
add action=accept chain=input comment="Allow Host WinBox/SSH via WAN" \
    dst-port=22,8291 in-interface=ether1 protocol=tcp
add action=drop chain=input comment=\
    "Block all internal subnets from managing router" disabled=yes dst-port=\
    22,23,80,443,8291 protocol=tcp
add action=accept chain=forward comment="Accept established transit traffic" \
    connection-state=established,related
add action=accept chain=forward comment="Allow SSH from WAN to Jump Server" \
    dst-address=10.0.1.2 dst-port=22 in-interface=ether1 protocol=tcp
add action=accept chain=forward comment="Bastion: Jump Server to VM1 SSH" \
    dst-address=10.0.2.2 dst-port=22 protocol=tcp src-address=10.0.1.2
add action=accept chain=forward comment="Bastion: Jump Server to VM2 SSH" \
    dst-address=10.0.2.3 dst-port=22 protocol=tcp src-address=10.0.1.2
add action=drop chain=forward comment="AWS SG: Block direct SSH to VM1" \
    disabled=yes dst-address=10.0.2.2 dst-port=22 protocol=tcp
add action=drop chain=forward comment="AWS SG: Block direct SSH to VM2" \
    dst-address=10.0.2.3 dst-port=22 protocol=tcp
add action=accept chain=forward comment=\
    "K3s Agents -> Host K3s Control Plane API" dst-port=6443 out-interface=\
    ether1 protocol=tcp
add action=accept chain=forward comment="K3s Agents -> Host Gitlab Registry" \
    dst-port=5050 out-interface=ether1 protocol=tcp
add action=accept chain=forward comment="Allow Private Subnet -> Internet" \
    connection-state=new in-interface=ether3 out-interface=ether1
add action=accept chain=forward comment="Allow Private Public -> Internet" \
    connection-state=new in-interface=ether2 out-interface=ether1
add action=accept chain=forward comment="Allow dstnat forwarded packets" \
    connection-nat-state=dstnat
add action=drop chain=forward comment=\
    "AWS Network ACL: Drop all unapproved cross-subnet routing" disabled=yes
/ip firewall nat
add action=masquerade chain=srcnat comment="AWS NAT Gateway" out-interface=\
    ether1
add action=dst-nat chain=dstnat comment=\
    "AWS ALB: Forward Port 80 -> Private K3s VM1 Port 80" dst-port=80 \
    in-interface=ether1 protocol=tcp to-addresses=10.0.2.2 to-ports=80
add action=dst-nat chain=dstnat comment=\
    "AWS ALB: Forward Port 80 -> Private K3s VM2 Port 80" dst-port=80 \
    in-interface=ether1 protocol=tcp to-addresses=10.0.2.3 to-ports=80
add action=dst-nat chain=dstnat comment=\
    "Expose K3s wibe-studio via Host Transit Port" dst-address=11.22.33.2 \
    dst-port=80 protocol=tcp to-addresses=10.0.2.2 to-ports=80
/ip route
add disabled=no dst-address=0.0.0.0/0 gateway=11.22.33.1 routing-table=main \
    suppress-hw-offload=no
