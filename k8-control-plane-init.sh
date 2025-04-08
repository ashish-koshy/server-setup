#!/bin/bash
set -e

source ./check-root.sh

DEFAULT_HOST_NAME="k8smaster.example.net"
HOST_NAME=${1:-$DEFAULT_HOST_NAME}

echo "Setting hostname to $HOST_NAME..."
hostnamectl set-hostname "$HOST_NAME"

# Initialize control plane
echo "Initializing Kubernetes control plane..."
kubeadm init --control-plane-endpoint="$HOST_NAME"

echo "Control plane initialized..."
