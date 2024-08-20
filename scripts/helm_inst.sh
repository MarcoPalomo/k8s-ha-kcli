# Getting Helm

curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Tying bitnami repository

helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Applying our setting up, from our value file

helm install my-wordpress bitnami/wordpress -f wordpress-values.yaml