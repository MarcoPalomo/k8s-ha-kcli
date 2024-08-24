#!/bin/bash

# Update the system
apt-get update -y
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
apt-get update -y

# Install Docker
apt-get install -y docker.io

# Install kubeadm, kubelet, and kubectl
apt-get install -y kubeadm kubelet kubectl

# Install etcd
apt-get install -y etcd

# Enable and start Docker and kubelet services
systemctl enable docker
systemctl start docker
systemctl enable kubelet
systemctl start kubelet

# Pull necessary Kubernetes images
sudo kubeadm config images pull

# Set up the firewall (if needed)
# ufw allow 6443/tcp
# ufw allow 2379:2380/tcp
# ufw allow 10250/tcp
# ufw allow 10251/tcp
# ufw allow 10252/tcp

# Disable swap
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Enable IP forwarding
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Load necessary kernel modules
mkdir -p /etc/containerd
touch /etc/containerd/config.toml
containerd config default > /etc/containerd/config.toml
modprobe br_netfilter
echo "br_netfilter" >> /etc/modules-load.d/k8s.conf
sed -i 's/            SystemdCgroup = false/            SystemdCgroup = true/' /etc/containerd/config.toml

# Helm cli to install
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

echo "Setup complete. Ready for kubeadm init or join."

