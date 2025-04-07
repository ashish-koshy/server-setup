#!/bin/bash
set -e

# Default values
DEFAULT_HOST_NAME="k8smaster.example.net"
DEFAULT_CALICO_VERSION="v3.29.3"

# Parse command line arguments
HOST_NAME=${1:-$DEFAULT_HOST_NAME}
CALICO_VERSION=${2:-$DEFAULT_CALICO_VERSION}

log() {
  echo "$1"
}

log "Setting up container network interface using CALICO..."
log "Hostname: $HOST_NAME"
log "Calico version: $CALICO_VERSION"

# Conditional Kubernetes cleanup
if command -v kubeclt &>/dev/null || [ -d "/etc/kubernetes" ]; then
  kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml
  kubectl config set-cluster kubernetes --server=https://${HOST_NAME}:6443
  kubectl get pods -n kube-system
  echo "Container Network Interface setup complete...."
else
  log "No Kubectl found..."
  exit 1
fi


