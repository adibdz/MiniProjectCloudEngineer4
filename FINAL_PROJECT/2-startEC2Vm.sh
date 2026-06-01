#!/usr/bin/env bash


VM1_IMAGE="./ec2vm/vm1.qcow2"
VM2_IMAGE="./ec2vm/vm2.qcow2"
JS_IMAGE="./ec2vm/js.qcow2"
BASE_IMAGE="./ec2vm/base.qcow2"

createVMDisk() {
    if [[ ! -f "$JS_IMAGE" ]]; then
        echo -n "[+] Creating VM disk : "
        qemu-img create -f qcow2 -b "$BASE_IMAGE" -F qcow2 "$VM1_IMAGE"
        qemu-img create -f qcow2 -b "$BASE_IMAGE" -F qcow2 "$VM2_IMAGE"
        qemu-img create -f qcow2 -b "$BASE_IMAGE" -F qcow2 "$JS_IMAGE"
        echo "created."
        sleep 2
    else
        echo "[+] VM disk already exist."
    fi
}

startVM() {
    echo -n "[+] Starting $VM1_IMAGE : "
    qemu-system-x86_64 -enable-kvm -cpu host -m 4G \
    -drive file="$VM1_IMAGE",if=virtio \
    -netdev tap,id=vm1priv,ifname=tap_vm1,script=no,downscript=no -device virtio-net-pci,netdev=vm1priv,mac=52:54:00:C0:00:01 \
    -nographic > /dev/null 2>&1  &
    echo "done."
    echo "  [-] Now you can ssh to it."
    sleep 2

    # echo -n "[+] Starting $VM2_IMAGE : "
    # qemu-system-x86_64 -enable-kvm -cpu host -m 2G \
    # -drive file="$VM2_IMAGE",if=virtio \
    # -netdev tap,id=vm2priv,ifname=tap_vm2,script=no,downscript=no -device virtio-net-pci,netdev=vm2priv,mac=52:54:00:D0:00:01 \
    # -nographic > /dev/null 2>&1  &
    # echo "done."
    # sleep 2

    # echo -n "[+] Starting $JS_IMAGE : "
    # qemu-system-x86_64 -enable-kvm -cpu host -m 1G \
    # -drive file="$JS_IMAGE",if=virtio \
    # -netdev tap,id=jspub,ifname=tap_js,script=no,downscript=no -device virtio-net-pci,netdev=jspub,mac=52:54:00:B0:00:01 \
    # -nographic > /dev/null 2>&1  &
    # echo "done."
    # sleep 2
}