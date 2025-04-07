#!/bin/bash
set -e

# Default values
DEFAULT_K8S_VERSION="v1.32"

# Parse command line arguments
K8S_VERSION=${1:-$DEFAULT_K8S_VERSION}

log() {
  echo "$1"
}

log "Kubernetes version selection : $K8S_VERSION"

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
  rm -rf $HOME/.kube
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
log "Docker installed."

# Install Kubernetes components
log "Installing Kubernetes $K8S_VERSION..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
log "Kubernetes installed."

# Configure containerd
log "Configuring containerd..."
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml >/dev/null
sed -i 's/disabled_plugins = \["cri"\]/enabled_plugins = \["cri"\]/' /etc/containerd/config.toml
systemctl restart containerd
log "Containerd configured."

log "Enabling Kublet..."
systemctl enable --now kubelet
log "Kublet enabled."

log "Checking kubectl, kubelet and kubectl installations..."
dpkg -l | grep kube
which kubeadm kubectl kubelet kubectl
