#!/bin/bash
set -e

source ./check-root.sh
source ./k8-cleanup.sh

echo "Starting Kubernetes setup process..."

# Disable swap
echo "Disabling swap..."
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
echo "Swap disabled successfully."

# Load necessary modules
echo "Loading required kernel modules..."
tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter
echo "Kernel modules loaded successfully."

# Configure sysctl settings
echo "Configuring sysctl settings for Kubernetes..."
tee /etc/sysctl.d/kubernetes.conf <<EOT
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOT

sysctl --system
echo "Sysctl settings configured successfully."

# Install dependencies
echo "Installing dependencies..."
apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates
echo "Dependencies installed successfully."

# Add Docker repository
echo "Adding Docker repository..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmour -o /etc/apt/trusted.gpg.d/docker.gpg
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
echo "Docker repository added successfully."

# Install containerd
echo "Installing containerd..."
apt update
apt install -y containerd.io
echo "Containerd installed successfully."

# Configure containerd
echo "Configuring containerd..."
containerd config default | tee /etc/containerd/config.toml >/dev/null 2>&1
sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
echo "Containerd configured successfully."

# Start and enable containerd
echo "Starting and enabling containerd service..."
systemctl restart containerd
systemctl enable containerd
echo "Containerd service started and enabled."

# Add Kubernetes repository
echo "Adding Kubernetes repository..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
echo "Kubernetes repository added successfully."

# Install Kubernetes components
echo "Installing Kubernetes components (kubelet, kubeadm, kubectl)..."
apt update
apt install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
echo "Kubernetes components installed successfully."

echo "Kubernetes setup completed successfully!"
echo "You can now initialize your Kubernetes cluster with 'kubeadm init'"
