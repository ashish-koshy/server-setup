#!/bin/bash
set -e

# Default values
DEFAULT_HOST_NAME="k8sworker1.example.net"

# Parse command line arguments
HOST_NAME=${1:-$DEFAULT_HOST_NAME}

log() {
  echo "$1"
}

log "Setting hostname to $HOST_NAME..."
hostnamectl set-hostname "$HOST_NAME"

# Initialize control plane
log "Initializing Kubernetes control plane..."
kubeadm init --control-plane-endpoint="$HOST_NAME"

log "Control plane initialized..."
