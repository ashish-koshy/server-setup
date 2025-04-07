# Usage for setting up K8:

## Control Plane:
    ./control-plane-setup.sh <HOSTNAME> [POD_CIDR] [K8S_VERSION] [PAUSE_VERSION] [DOCKER_VERSION]

## Worker Node:
    ./worker-setup.sh <HOSTNAME> [K8S_VERSION] [PAUSE_VERSION] [DOCKER_VERSION]

## Notes:
- The control plane script generates the join command automatically during initialization
- Worker nodes need to be joined manually using the command from the control plane output
- Both scripts maintain idempotency - can be safely rerun
- Network configuration (like Calico or Flannel) should be installed separately after control plane initialization

