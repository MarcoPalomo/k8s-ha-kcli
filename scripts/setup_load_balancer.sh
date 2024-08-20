#!/bin/bash

# Check if control plane nodes are provided
if [ $# -eq 0 ]; then
    echo "No control plane nodes provided. Usage: $0 <node1> <node2> <node3> ..."
    exit 1
fi

# Update the system
apt-get update

# Install HAProxy
apt-get install -y haproxy

# Configure HAProxy
cat > /etc/haproxy/haproxy.cfg << EOF
global
    log /dev/log    local0
    log /dev/log    local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000

frontend kubernetes
    bind *:6443
    mode tcp
    option tcplog
    default_backend kubernetes-backend

backend kubernetes-backend
    mode tcp
    option tcp-check
    balance roundrobin
EOF

# Add control plane nodes to the backend
for node in "$@"
do
    echo "    server ${node} ${node}:6443 check fall 3 rise 2" >> /etc/haproxy/haproxy.cfg
done

# Restart HAProxy to apply changes
systemctl restart haproxy

echo "Load balancer setup complete."