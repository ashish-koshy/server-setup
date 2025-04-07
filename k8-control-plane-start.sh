#!/bin/bash
set -e

# Default values
DEFAULT_CALICO_VERSION="v3.29.3"

# Parse command line arguments
CALICO_VERSION=${1:-$DEFAULT_CALICO_VERSION}

log() {
  echo "$1"
}

log "Calico version selection : $CALICO_VERSION"

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl cluster-info
kubectl get nodes

kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml
kubectl get pods -n kube-system

log "Control plane is ready for worker nodes..."
