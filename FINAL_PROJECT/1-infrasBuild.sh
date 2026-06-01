#!/usr/bin/env bash

# Run this script from root folder project

BASE_IMAGE="./ec2vm/base.qcow2"
MINI_ISO="./ec2vm/deb12Netist.iso"
MIKROTIK_DISK="./mikrotik/mikrotik7.qcow2"
MIKROTIK_CHR="./mikrotik/chr7.img"
WIFI_INTERFACE="wlp1s0" # Adjust to yours, see on `ip a`
BRIDGE_WAN="br_wan"
BRIDGE_PUBLIC="br_public"
BRIDGE_PRIVATE="br_private"
ALLBRIDGES=("$BRIDGE_WAN" "$BRIDGE_PUBLIC" "$BRIDGE_PRIVATE")
CURRENT_DIR=$(basename "$PWD")

clearScreen() {
    clear
}

mustBeInRootFolder() {
    if [[ "$CURRENT_DIR" != "final-project" ]]; then
        echo "[+] Error: This script must be run from the 'final-project' root directory."
        exit 1
    fi
}

mustBeRoot() {
    if [[ $EUID -ne 0 ]]; then 
        echo "[+] Error: Please run as root"; 
        exit; 
    fi
}

buildAWSMimicInfra() {
    # Build Virtual Bridge & TAPs
    echo "[+] Building the Bridges and Taps"
    for br in "${ALLBRIDGES[@]}"; do
        if [[ $br == $BRIDGE_WAN ]]; then
            if [[ ! -d /sys/class/net/$br ]]; then 
                ip link add name $br type bridge
                ip link set $br up
            fi
            [[ -z $(ip addr show $br | grep "11.22.33.1") ]] && ip addr add 11.22.33.1/30 dev $br
            if [[ ! -d /sys/class/net/tap_wan ]]; then 
                ip tuntap add dev tap_wan mode tap
                ip link set tap_wan master $BRIDGE_WAN && ip link set tap_wan up
            fi
            echo "  [+] Setting up $br and tap_wan success"
        elif [[ $br == $BRIDGE_PUBLIC ]]; then
            if [[ ! -d /sys/class/net/$br ]]; then 
                ip link add name $br type bridge
                ip link set $br up
            fi
            if [[ ! -d /sys/class/net/tap_public ]]; then 
                ip tuntap add dev tap_public mode tap
                ip link set tap_public master $BRIDGE_PUBLIC
                ip link set tap_public up
            fi
            if [[ ! -d /sys/class/net/tap_js ]]; then 
                ip tuntap add dev tap_js mode tap
                ip link set tap_js master $BRIDGE_PUBLIC
                ip link set tap_js up
            fi
            echo "  [+] Setting up $br, tap_public, tap_js success"
        elif [[ $br == $BRIDGE_PRIVATE ]]; then
            if [[ ! -d /sys/class/net/$br ]]; then 
                ip link add name $br type bridge
                ip link set $br up
            fi
            if [[ ! -d /sys/class/net/tap_private ]]; then 
                ip tuntap add dev tap_private mode tap
                ip link set tap_private master $BRIDGE_PRIVATE
                ip link set tap_private up
            fi
            if [[ ! -d /sys/class/net/tap_vm1 ]]; then 
                ip tuntap add dev tap_vm1 mode tap
                ip link set tap_vm1 master $BRIDGE_PRIVATE
                ip link set tap_vm1 up
            fi
            if [[ ! -d /sys/class/net/tap_vm2 ]]; then 
                ip tuntap add dev tap_vm2 mode tap
                ip link set tap_vm2 master $BRIDGE_PRIVATE
                ip link set tap_vm2 up
            fi
            echo "  [+] Setting up $br, tap_private, tap_vm1, tap_vm2 success"
        else
            echo "  [+] Error creating Bridge $br and Taps"
        fi
        sleep 2
    done    
}

createEC2qcow2() {
    if [[ ! -e $BASE_IMAGE ]]; then
        qemu-img create -f qcow2 "$BASE_IMAGE" 10G
        echo "[+] The $BASE_IMAGE was created."
        
        qemu-system-x86_64 -enable-kvm -cpu host -m 2G \
        -drive file="$BASE_IMAGE",if=virtio -cdrom "$MINI_ISO" -boot d
        echo "[+] Debian was installed to $BASE_IMAGE."
        
        sleep 2
    else
        echo "[+] The $BASE_IMAGE already exist. "
    fi
}

theFirewallNatForMikrotik() {
    sysctl -w net.ipv4.ip_forward=1 > /dev/null 2>&1
    # script detek otomatis interface wifi
    iptables -t nat -A POSTROUTING -o $WIFI_INTERFACE -j MASQUERADE
    iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
}

startMikrotik() {
    echo "[+] Building Mikrotik QCOW2 IMAGE"
    if [[ ! -f $MIKROTIK_DISK ]]; then
        if [[ -f $MIKROTIK_CHR ]]; then
            echo "  [+] Converting chr.img to qcow2"
            echo "  [+] You must start manually qemu mikrotik"
            qemu-img convert -f raw -O qcow2 "$MIKROTIK_CHR" "$MIKROTIK_DISK"
        else
            echo "  [+] Error: Neither $MIKROTIK_DISK nor chr.img found!"
            exit 1
        fi
    else
        echo "  [+] The $MIKROTIK_DISK image already exists."
        qemu-system-x86_64 -enable-kvm -cpu host -m 512 \
        -drive file="$MIKROTIK_DISK",if=virtio \
        -netdev tap,id=wan,ifname=tap_wan,script=no,downscript=no -device virtio-net-pci,netdev=wan,mac=52:54:00:A0:00:00 \
        -netdev tap,id=pub,ifname=tap_public,script=no,downscript=no -device virtio-net-pci,netdev=pub,mac=52:54:00:A0:00:01 \
        -netdev tap,id=priv,ifname=tap_private,script=no,downscript=no -device virtio-net-pci,netdev=priv,mac=52:54:00:A0:00:02 \
        -nographic > /dev/null 2>&1  &
        echo -n "[+] Power on Mikrotik VM : "
        sleep 5
        echo "success!"
        sleep 1
    fi
}

clearScreen
mustBeInRootFolder
mustBeRoot
buildAWSMimicInfra
createEC2qcow2
theFirewallNatForMikrotik
startMikrotik
# cleanup