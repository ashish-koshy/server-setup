#!/bin/bash
set -e

# Default values
DEFAULT_K8S_VERSION="v1.32"
DEFAULT_PAUSE_IMAGE_VERSION="3.10"
DEFAULT_DOCKER_VERSION="latest"

# Parse command line arguments
HOST_NAME=$1
K8S_VERSION=${2:-$DEFAULT_K8S_VERSION}
PAUSE_IMAGE_VERSION=${3:-$DEFAULT_PAUSE_IMAGE_VERSION}
DOCKER_VERSION=${4:-$DEFAULT_DOCKER_VERSION}

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log "Setting hostname to $HOST_NAME..."
sudo hostnamectl set-hostname "$HOST_NAME"

log "Starting worker installation with parameters:"
log "Hostname: $HOST_NAME"
log "Kubernetes version: $K8S_VERSION"
log "Pause image version: $PAUSE_IMAGE_VERSION"
log "Docker version: $DOCKER_VERSION"

# Common setup steps (same as control plane)
log "Disabling swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

log "Loading kernel modules..."
sudo tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

log "Configuring sysctl..."
sudo tee /etc/sysctl.d/kubernetes.conf <<EOT
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOT
sudo sysctl --system

# Conditional cleanup
if command -v kubeadm &>/dev/null || [ -d "/etc/kubernetes" ]; then
  log "Removing Kubernetes components..."
  kubeadm reset -f || true
  systemctl stop kubelet || true
  apt-get remove --purge -y kubeadm kubectl kubelet || true
  rm -rf /etc/kubernetes ~/.kube /var/lib/kubelet
else
  log "No Kubernetes components found"
fi

if command -v docker &>/dev/null; then
  log "Removing Docker..."
  systemctl stop docker
  apt-get remove --purge -y docker-ce docker-ce-cli containerd.io
  rm -rf /var/lib/docker
else
  log "No Docker components found"
fi

# Install Docker
log "Installing Docker..."
apt-get update
apt-get install -y ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io
systemctl enable --now docker

# Install Kubernetes components
log "Installing Kubernetes..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

log "Worker node setup complete! Join this node to the cluster using the join command from the control plane."
