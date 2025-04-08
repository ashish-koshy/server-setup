#!/bin/bash
set -e

DEFAULT_CALICO_VERSION="v3.29.3"
CALICO_VERSION=${1:-$DEFAULT_CALICO_VERSION}

echo "Calico version selection : $CALICO_VERSION"

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl cluster-info
kubectl get nodes

kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml
kubectl get pods -n kube-system

echo "Control plane is ready for worker nodes..."
