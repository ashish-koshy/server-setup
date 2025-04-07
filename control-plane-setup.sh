#!/bin/bash
set -e

# Default values
DEFAULT_HOST_NAME="k8smaster.example.net"
DEFAULT_POD_NETWORK_CIDR="192.168.0.0/16"
DEFAULT_K8S_VERSION="v1.32"
DEFAULT_CALICO_VERSION="v3.29.3"

# Parse command line arguments
HOST_NAME=${1:-$DEFAULT_HOST_NAME}
POD_NETWORK_CIDR=${2:-$DEFAULT_POD_NETWORK_CIDR}
K8S_VERSION=${3:-$DEFAULT_K8S_VERSION}
CALICO_VERSION=${4:-$DEFAULT_CALICO_VERSION}

log() {
  echo "$1"
}

log "Setting hostname to $HOST_NAME..."
hostnamectl set-hostname "$HOST_NAME"

log "Starting control plane installation with parameters:"
log "Hostname: $HOST_NAME"
log "Pod Network CIDR: $POD_NETWORK_CIDR"
log "Kubernetes version: $K8S_VERSION"
log "Calico version: $CALICO_VERSION"

# Disable swap
log "Disabling swap..."
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
log "Swap disabled"

# Load kernel modules
log "Loading kernel modules..."
tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter
log "Modules loaded"

# Sysctl configuration
log "Configuring sysctl..."
tee /etc/sysctl.d/kubernetes.conf <<EOT
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOT
sysctl --system
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
  rm -f /etc/apt/keyrings/kubernetes-archive-keyring.gpg
  rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  rm -f /etc/apt/sources.list.d/kubernetes.list
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
  rm -f /etc/apt/keyrings/docker.gpg
  rm -f /etc/apt/sources.list.d/docker.list
else
  log "No existing Docker components found"
fi

# Restore Default iptables Rules
log "Resetting IPTABLES..."
FILE="iptables-default.rules"
echo "*filter" > $FILE
echo ":INPUT ACCEPT [0:0]" >> $FILE
echo ":FORWARD ACCEPT [0:0]" >> $FILE
echo ":OUTPUT ACCEPT [0:0]" >> $FILE
echo "COMMIT" >> $FILE

# Reset iptables
apt-get install -y iptables-persistent
iptables-restore < iptables-default.rules
iptables -A INPUT -p tcp --dport 6443 -j ACCEPT
netfilter-persistent save
netfilter-persistent reload

# Install Docker
log "Installing Docker..."
apt-get update
apt-get install -y ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io
systemctl enable --now docker
log "Docker installed"

# Install Kubernetes components
log "Installing Kubernetes $K8S_VERSION..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
log "Kubernetes installed"

# Configure containerd
log "Configuring containerd..."
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml >/dev/null
sed -i 's/disabled_plugins = \["cri"\]/enabled_plugins = \["cri"\]/' /etc/containerd/config.toml
systemctl restart containerd
log "Containerd configured"

log "Enabling kublet"
systemctl enable --now kubelet
log "kublet enabled"

log "Checking kubectl, kubelet and kubectl installations"
dpkg -l | grep kube
which kubeadm kubectl kubelet kubectl

# Initialize control plane
log "Initializing Kubernetes control plane..."
kubeadm init \
  --control-plane-endpoint="$HOST_NAME" \
  --pod-network-cidr="$POD_NETWORK_CIDR"

# Setup kubeconfig for root (since script is run as sudo)
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config
chown root:root /root/.kube/config

# Also set up kubeconfig for the actual sudo user
if [ -n "$SUDO_USER" ]; then
  USER_HOME=$(eval echo "~$SUDO_USER")
  mkdir -p $USER_HOME/.kube
  cp -i /etc/kubernetes/admin.conf $USER_HOME/.kube/config
  chown $(id -u "$SUDO_USER"):$(id -g "$SUDO_USER") $USER_HOME/.kube/config
fi
log "Control plane initialized"

kubectl config set-cluster kubernetes --server=https://${HOST_NAME}:6443

# Verify installation
log "Verifying cluster status..."
kubectl cluster-info
kubectl get nodes

log "Applying Container Network Interface..."
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml
kubectl get pods -n kube-system

echo "Control plane setup complete! Use the join command above to add worker nodes."
