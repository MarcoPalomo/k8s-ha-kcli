#!/bin/bash

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg


# Update the system
apt-get update -y

# Install Docker
apt-get install -y docker.io

# Install kubeadm and kubelet (kubectl not necessary for worker nodes)
apt-get install -y kubeadm kubelet

# Enable and start Docker and kubelet services
systemctl enable docker
systemctl start docker
systemctl enable kubelet
systemctl start kubelet

# Set up the firewall (if needed)
# ufw allow 10250/tcp
# ufw allow 30000:32767/tcp

# Disable swap
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Enable IP forwarding
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Load necessary kernel modules
modprobe br_netfilter
echo "br_netfilter" >> /etc/modules-load.d/k8s.conf

echo "Worker node setup complete. Ready for kubeadm join."