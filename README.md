        
        mkdir -p $HOME/.kube
        sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
        sudo chown $(id -u):$(id -g) $HOME/.kube/config

        # Verify installation
        log "Verifying cluster status..."
        kubectl cluster-info
        kubectl get nodes

        log "Applying CALICO Container Network Interface..."
        kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml
        kubectl get pods -n kube-system

        
