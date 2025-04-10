#!/bin/bash
set -e

source ./check-root.sh

DEFAULT_K8S_VERSION="v1.32"
K8S_VERSION=${1:-$DEFAULT_K8S_VERSION}

source ./k8s-cleanup.sh

echo "Kubernetes version selection : $K8S_VERSION"

# Restore Default iptables Rules
echo "Resetting IPTABLES..."
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
echo "Installing Docker..."
apt-get update
apt-get install -y ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io
systemctl enable --now docker
echo "Docker installed."

# Install Kubernetes components
echo "Installing Kubernetes $K8S_VERSION..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
echo "Kubernetes installed."

# Configure containerd
echo "Configuring containerd..."
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml >/dev/null
sed -i 's/disabled_plugins = \["cri"\]/enabled_plugins = \["cri"\]/' /etc/containerd/config.toml
systemctl restart containerd
echo "Containerd configured."

echo "Enabling Kublet..."
systemctl enable --now kubelet
echo "Kublet enabled."

echo "Checking kubectl, kubelet and kubectl installations..."
dpkg -l | grep kube
which kubeadm kubectl kubelet kubectl

echo "Kubernetes components have been installed..."
