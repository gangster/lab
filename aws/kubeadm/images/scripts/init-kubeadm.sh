#!/bin/bash
set -x

INTERNAL_IP=$(hostname -I | awk '{print $1}')
cat <<EOF | sudo tee /etc/default/kubelet
KUBELET_EXTRA_ARGS='--node-ip ${INTERNAL_IP}'
EOF

POD_CIDR=10.244.0.0/16
SERVICE_CIDR=10.96.0.0/16
sudo kubeadm init --pod-network-cidr $POD_CIDR --service-cidr $SERVICE_CIDR --apiserver-advertise-address $INTERNAL_IP --ignore-preflight-errors=NumCPU,Mem | sudo tee  /tmp/kubeadm.log