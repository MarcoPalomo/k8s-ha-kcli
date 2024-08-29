# Variables
PYTHON := python3
PIP := pip3
# CONTROL_PLANE_NODES and WORKER_NODES to instruct with 
# for i in $(kcli list vm | grep "master OR worker" | awk '{print $6}'); do echo $i; done
CONTROL_PLANE_NODES :=192.168.122.128#192.168.122.180 192.168.122.130
WORKER_NODES := 192.168.122.29#192.168.122.32 192.168.122.204
# Same for loadbalancer IP value
# Due to a lab on my laptop, I have under dimensioned my nodes and only put a LB. Another one is preffered to gaine more HA
LOAD_BALANCER := 192.168.122.26
API_SERVER_IP := 192.168.122.128
KUBECONFIG_PATH := ~/.kube/config

# Phony targets
.PHONY: all setup clean install run test help

# Default target
all: setup run

# Setup the k8s cluster
setup: setup-control-plane setup-workers setup-lb
	
# Clean the project
clean:
	@echo "Cleaning up everything..."
	find . -type f -name '*.pyc' -delete
	find . -type d -name '__pycache__' -delete

# Install dependencies
install:
	@echo "Installing dependencies..."
	$(PIP) install -r requirements.txt

# Setup of the infra
infra-up:
	@echo "Spining up the complete infrastructure"
	@kcli create plan -f k8s-ha-plan-white.yaml k8s-ha-cluster

# Deleting the infrastructure
infra-down:
	@echo "Deleting the Infrastructure"
	@kcli delete plan k8s-ha-cluster

# Setup control plane nodes
setup-control-plane:
	@echo "Setting up control plane nodes..."
	for node in $(CONTROL_PLANE_NODES); do \
		scp scripts/setup_control_plane.sh ubuntu@$$node:/tmp/; \
		ssh ubuntu@$$node 'sudo bash /tmp/setup_control_plane.sh'; \
	done

# Setup worker nodes
setup-workers:
	@echo "Setting up worker nodes..."
	for node in $(WORKER_NODES); do \
		scp scripts/setup_worker_node.sh ubuntu@$$node:/tmp/; \
		ssh ubuntu@$$node 'sudo bash /tmp/setup_worker_node.sh'; \
	done

# Setup load balancer
setup-lb:
	@echo "Setting up load balancer..."
	scp scripts/setup_load_balancer.sh ubuntu@$(LOAD_BALANCER):/tmp/
	ssh ubuntu@$(LOAD_BALANCER) 'sudo bash /tmp/setup_load_balancer.sh $(CONTROL_PLANE_NODES)'

# Initialize the cluster
init-cluster:
	@echo "Initializing the cluster..."
	ssh ubuntu@$(word 1,$(CONTROL_PLANE_NODES)) 'sudo kubeadm reset -f && sudo kubeadm init --service-cidr=192.168.122.0/24 --control-plane-endpoint "$(API_SERVER_IP):6443" --upload-certs --ignore-preflight-errors=true'

# Please modify the <master1-ip-address> placeholder
get-join-command:
	@ssh ubuntu@<master1-ip-address> "sudo kubeadm token create --print-join-command"

# Join the worker nodes to the cluster
join-workers: get-join-command
	@$(eval JOIN_COMMAND := $(shell make get-join-command))
	@for node in $(WORKER_NODES); do \
        ssh ubuntu@$$node "sudo $(JOIN_COMMAND)"; \
    done

#Get your kubeconfig
generate-kubeconfig:
	@ssh user@$(MASTER_IP) "sudo cat /etc/kubernetes/admin.conf" > $(KUBECONFIG_PATH)
	@sed -i 's/server: https:\/\/127.0.0.1:6443/server: https:\/\/$(LOAD_BALANCER):6443/' $(KUBECONFIG_PATH)
	@chmod 600 $(KUBECONFIG_PATH)
	@echo "Kubeconfig generated at $(KUBECONFIG_PATH)"
	@echo "Run 'export KUBECONFIG=$(KUBECONFIG_PATH)' to use it"

# Test the cluster
test: generate-kubeconfig
    KUBECONFIG=$(KUBECONFIG_PATH) kubectl get nodes

# Wordpress deployment
wp:
	@echo "Starting the deployment of Wordpress" 
	@helm install my-wp ./wordpress-nfs -f wordpress-nfs/values.yaml -n niceAmbien --create-namespace

# Help
help:
	@echo "Available targets:"
	@echo "  all               : Set up and run (default)"
	@echo "  setup             : Set up the HA cluster"
	@echo "  clean             : Clean up generated files"
	@echo "  install           : Install dependencies"
	@echo "  infra-up          : Create the infrastructure"
	@echo "  infra-down        : Delete the infrastructure"
	@echo "  setup-control-plane : Set up control plane nodes"
	@echo "  setup-workers     : Set up worker nodes"
	@echo "  setup-lb          : Set up load balancer"
	@echo "  join-workers      : Join the worker nodes to the cluster"
	@echo "  init-cluster      : Initialize the Kubernetes cluster"
	@echo "  generate-kubeconfig : Get your kubeconfig ready to use"
	@echo "  test              : Test the cluster"
	@echo "  wp                : Install helm and deploy the Wordpress"
	@echo "  help              : Show this help message"
