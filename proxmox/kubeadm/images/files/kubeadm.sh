#!/bin/bash
set -x

KUBE_LATEST=$(curl -L -s https://dl.k8s.io/release/stable.txt | awk 'BEGIN { FS="." } { printf "%s.%s", $1, $2 }')
export KUBE_LATEST
mkdir -p /etc/apt/keyrings

# Check if the GPG key file already exists
GPG_KEY_PATH="/etc/apt/keyrings/kubernetes-apt-keyring.gpg"
if [ -f "$GPG_KEY_PATH" ]; then
    echo "GPG key file already exists. Skipping key download."
else
    # Fetch and process GPG key
    GPG_KEY_URL="https://pkgs.k8s.io/core:/stable:/$KUBE_LATEST/deb/Release.key"
    curl -fsSL "$GPG_KEY_URL" | sudo gpg --batch --no-tty --dearmor -o "$GPG_KEY_PATH"
    if [ $? -ne 0 ]; then
        echo "Error fetching or processing GPG key."
        exit 1
    fi
fi

echo "deb [signed-by=$GPG_KEY_PATH] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update -y
sudo crictl config \
    --set runtime-endpoint=unix:///run/containerd/containerd.sock \
    --set image-endpoint=unix:///run/containerd/containerd.sock

sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

INTERNAL_IP=$(hostname -I | awk '{print $1}')
cat <<EOF | sudo tee /etc/default/kubelet
KUBELET_EXTRA_ARGS='--node-ip ${INTERNAL_IP}'
EOF

POD_CIDR=10.244.0.0/16
SERVICE_CIDR=10.96.0.0/16
sudo kubeadm init --pod-network-cidr $POD_CIDR --service-cidr $SERVICE_CIDR --apiserver-advertise-address $INTERNAL_IP --ignore-preflight-errors=NumCPU | sudo tee  /tmp/kubeadm.log