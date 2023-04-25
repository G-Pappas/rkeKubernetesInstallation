#!/bin/bash

# Fix time on the host
sudo apt-get install htpdate
sudo timedatectl set-timezone Europe/Athens
sudo htpdate -a google.com

# Enable ssh password authentication
echo "Enable SSH password authentication:"
sudo sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
sudo systemctl reload sshd

# Set Root password
#echo "Set root password:"
#echo -e "iamadmin\niamadmin" | passwd root >/dev/null 2>&1
sudo passwd root

# Commands for all K8s nodes
# Add Docker GPG key, Docker Repo, install Docker and enable services
# Add repo and Install packages

sudo apt update -y
sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates
curl https://releases.rancher.com/install-docker/20.10.sh | sh
sudo apt update -y
sudo usermod -aG docker cosmote
sudo usermod -aG docker root

#Download the Google Cloud public signing key for kubectl
sudo curl -fsSLo /etc/apt/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg


# Create required directories
sudo mkdir -p /etc/systemd/system/docker.service.d

# Create daemon json config file
sudo tee /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

# Start and enable Services
sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl enable docker

# Turn off swap
# The Kubernetes scheduler determines the best available node on
# which to deploy newly created pods. If memory swapping is allowed
# to occur on a host system, this can lead to performance and stability
# issues within Kubernetes.
# For this reason, Kubernetes requires that you disable swap in the host system.
# If swap is not disabled, kubelet service will not start on the masters and nodes
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
sudo swapoff -a

# Turn off firewall
sudo ufw disable

# Modify bridge adapter setting
# Configure sysctl.
sudo modprobe overlay
sudo modprobe br_netfilter

sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

# Ensure that the br_netfilter module is loaded
lsmod | grep br_netfilter
