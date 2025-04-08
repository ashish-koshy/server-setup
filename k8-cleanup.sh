#!/bin/bash
set -e

# Conditional Kubernetes cleanup
if command -v kubeadm &>/dev/null || [ -d "/etc/kubernetes" ]; then
  echo "Cleaning up K8..."
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
  echo "No existing instances of K8 to be cleaned up..."
fi

# Conditional Docker cleanup
if command -v docker &>/dev/null || systemctl list-unit-files | grep -q docker.service; then
  echo "Cleaning up Docker..."
  systemctl stop docker || true
  systemctl disable docker || true
  apt-get remove --purge -y docker-ce docker-ce-cli containerd.io || true
  apt-get autoremove -y || true
  rm -rf /var/lib/docker /var/lib/containerd /etc/docker
  rm -f /etc/apt/keyrings/docker.gpg
  rm -f /etc/apt/sources.list.d/docker.list
else
  echo "No existing instances of Docker to be cleaned up..."
fi
