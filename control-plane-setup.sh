#!/bin/bash
set -e

# Default values
DEFAULT_K8S_VERSION="v1.32"
DEFAULT_PAUSE_IMAGE_VERSION="3.10"
DEFAULT_DOCKER_VERSION="latest"
DEFAULT_POD_NETWORK_CIDR="10.244.0.0/16"

# Parse command line arguments
HOST_NAME=$1
POD_NETWORK_CIDR=${2:-$DEFAULT_POD_NETWORK_CIDR}
K8S_VERSION=${3:-$DEFAULT_K8S_VERSION}
PAUSE_IMAGE_VERSION=${4:-$DEFAULT_PAUSE_IMAGE_VERSION}
DOCKER_VERSION=${5:-$DEFAULT_DOCKER_VERSION}

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log "Setting hostname to $HOST_NAME..."
sudo hostnamectl set-hostname "$HOST_NAME"

log "Starting control plane installation with parameters:"
log "Hostname: $HOST_NAME"
log "Pod Network CIDR: $POD_NETWORK_CIDR"
log "Kubernetes version: $K8S_VERSION"
log "Pause image version: $PAUSE_IMAGE_VERSION"
log "Docker version: $DOCKER_VERSION"

# Disable swap
log "Disabling swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
log "Swap disabled"

# Load kernel modules
log "Loading kernel modules..."
sudo tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter
log "Modules loaded"

# Sysctl configuration
log "Configuring sysctl..."
sudo tee /etc/sysctl.d/kubernetes.conf <<EOT
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOT
sudo sysctl --system
log "Sysctl configured"

# Conditional Kubernetes cleanup
if command -v kubeadm &>/dev/null || [ -d "/etc/kubernetes" ]; then
  log "Removing existing Kubernetes components..."
  kubeadm reset -f || true
  systemctl stop kubelet || true
  systemctl disable kubelet || true
  apt-mark unhold kubeadm kubectl kubelet || true
  apt-get remove --purge -y kubeadm kubectl kubelet kubernetes-cni cri-tools || true
  apt-get autoremove -y || true
  rm -rf /etc/kubernetes ~/.kube /var/lib/etcd /var/lib/kubelet /etc/cni/net.d
else
  log "No existing Kubernetes components found"
fi

# Conditional Docker cleanup
if command -v docker &>/dev/null || systemctl list-unit-files | grep -q docker.service; then
  log "Removing existing Docker components..."
  systemctl stop docker || true
  systemctl disable docker || true
  apt-get remove --purge -y docker-ce docker-ce-cli containerd.io || true
  apt-get autoremove -y || true
  rm -rf /var/lib/docker /var/lib/containerd /etc/docker
else
  log "No existing Docker components found"
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
log "Docker installed"

# Install Kubernetes components
log "Installing Kubernetes $K8S_VERSION..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
log "Kubernetes installed"

# Configure containerd
log "Configuring containerd..."
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
log "Containerd configured"

# Initialize control plane
log "Initializing Kubernetes control plane..."
sudo kubeadm init \
  --control-plane-endpoint="$HOST_NAME" \
  --pod-network-cidr="$POD_NETWORK_CIDR" \
  --upload-certs \
  --skip-phases=addon/kube-proxy

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
log "Control plane initialized"

# Verify installation
log "Verifying cluster status..."
kubectl cluster-info
kubectl get nodes

echo "Control plane setup complete! Use the join command above to add worker nodes."
