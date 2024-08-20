import os, subprocess

#definition of run_command for the cli activities
def run_command(command):
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, universal_newlines=True)
    output, error = process.communicate()
    return_code = process.returncode
    
    if return_code != 0:
        print(f"Error executing command: {command}")
        print(f"Error message: {error}")
    
    return output, error, return_code

#def prepare_kvm_instances(vm):
#    run_command(f"curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl"))

def setup_control_plane(node):
    script_path = os.path.join('scripts', 'setup_control_plane.sh')
    run_command(f"scp {script_path} {node}:/tmp/setup_control_plane.sh")
    run_command(f"ssh {node} 'bash /tmp/setup_control_plane.sh'")

def setup_load_balancer(lb_node, control_plane_nodes):
    script_path = os.path.join('scripts', 'setup_load_balancer.sh')
    config_path = os.path.join('config', 'haproxy.cfg')
    run_command(f"scp {script_path} {config_path} {lb_node}:/tmp/")
    run_command(f"ssh {lb_node} 'bash /tmp/setup_load_balancer.sh {' '.join(control_plane_nodes)}'")

# Passing the whole config into data
def configure_haproxy(config):
    haproxy_config = """
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
    mode    tcp
    option  tcplog
    option  dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000

frontend kubernetes
    bind *:6443
    option tcplog
    mode tcp
    default_backend kubernetes-master-nodes

backend kubernetes-master-nodes
    mode tcp
    balance roundrobin
    option tcp-check
"""


    for i, ip in enumerate(config['master_ips'], start=1):
        haproxy_config += f"    server master{i} {ip}:6443 check fall 3 rise 2\n"

    return haproxy_config

def install_cni(master_node):
    cni_path = os.path.join('templates', 'calico.yaml')
    run_command(f"scp {cni_path} {master_node}:/tmp/calico.yaml")
    run_command(f"ssh {master_node} 'kubectl apply -f /tmp/calico.yaml'")

def main():
    control_plane_nodes = ["master1", "master2", "master3"]
    worker_nodes = ["worker1", "worker2", "worker3"]
    load_balancer = "lb1"
    api_server_ip = "192.168.1.100"  # IP of the load balancer

    # Setup control plane nodes
    for node in control_plane_nodes:
        setup_control_plane(node)

    # haproxy config
        config = {
        'master_ips': ['192.168.1.10', '192.168.1.11', '192.168.1.12'],  # Replace with your actual master IPs
        'haproxy_ip': '192.168.1.100',  # Replace with your HAProxy IP
        # ... other configuration items ...
    }

    # Generate HAProxy configuration
    haproxy_config = configure_haproxy(config)

    # Save HAProxy configuration to a file
    with open('haproxy.cfg', 'w') as f:
        f.write(haproxy_config)

    # Deploy HAProxy (this is a placeholder - implement based on your deployment method)
    deploy_haproxy(config['haproxy_ip'], 'haproxy.cfg')

    # ...

def deploy_haproxy(ip, config_file):
    # This is a placeholder function. Implement the actual deployment logic here.
    # This could involve using SSH to copy the config file and restart HAProxy,
    # or using your infrastructure-as-code tool to deploy HAProxy.
    print(f"Deploying HAProxy to {ip} with config file {config_file}")


if __name__ == "__main__":
    main()

