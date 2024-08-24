#!/bin/bash

#setting the necessary packets
sudo apt-get update
sudo apt-get install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst

#passwd of the user
cat >user-data.txt <<EOF
password: toto
chpasswd: { expire: False }
ssh_pwauth: True
EOF
cloud-localds user-data.img user-data.txt

# VM configuration
VM_IMAGE="./ubuntu-vm-disk.qcow2"  # Path to your base image
VM_SIZE="10G"  # Disk size for each VM
VM_RAM="1024"  # RAM for each VM in MB
VM_VCPUS="2"   # Number of vCPUs for each VM
BRIDGE_INTERFACE="virbr0"  # Your bridge interface, usually virbr0

# Function to create a VM
create_vm() {
    local vm_name=$1
    local vm_ip=$2

    echo "Creating VM: $vm_name with IP: $vm_ip"

    # Create a copy of the base image
    qemu-img create -f qcow2 -b $VM_IMAGE $vm_name.qcow2 $VM_SIZE

    # Create the VM
    virt-install \
        --name $vm_name \
        --ram $VM_RAM \
        --vcpus $VM_VCPUS \
        --disk path=$vm_name.qcow2,format=qcow2 \
        --os-variant ubuntu22.04 \
        --network bridge=$BRIDGE_INTERFACE \
        --graphics none \
        --console pty,target_type=serial \
        --import \
        --noautoconsole

    # Set static IP (this assumes your base image uses Netplan)
    # You may need to adjust this based on your image configuration
    virsh start $vm_name
    sleep 10  # Wait for VM to start
    virsh domifaddr $vm_name
    MAC=$(virsh domifaddr $vm_name | grep ipv4 | awk '{print $2}')
    
    virsh dumpxml $vm_name > $vm_name.xml
    sed -i "s/mac address='$MAC'/mac address='$MAC'\\n      <ip address='$vm_ip' family='ipv4'\\/>/" $vm_name.xml
    virsh define $vm_name.xml

    echo "VM $vm_name created and configured with IP $vm_ip"
}

# Create master nodes
create_vm "master1" "192.168.122.11"
create_vm "master2" "192.168.122.12"
create_vm "master3" "192.168.122.13"

# Create worker nodes
create_vm "worker1" "192.168.122.21"
create_vm "worker2" "192.168.122.22"
create_vm "worker3" "192.168.122.23"

echo "All VMs created successfully!"