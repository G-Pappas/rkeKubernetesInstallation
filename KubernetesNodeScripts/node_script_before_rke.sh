#!/bin/bash

password=$1
# Fix time on the host
echo "$password" | sudo apt-get install htpdate
echo "$password" | sudo timedatectl set-timezone Europe/Athens
echo "$password" | sudo htpdate -a google.com

# Enable ssh password authentication
echo "Enable SSH password authentication:"
echo "$password" | sudo sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
echo "$password" | sudo echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
echo "$password" | sudo systemctl reload sshd

# Set Root password
#echo "Set root password:"
#echo -e "iamadmin\niamadmin" | passwd root >/dev/null 2>&1
echo -e "$password\n$password\n$password" | sudo passwd root

# Commands for all K8s nodes
# Add Docker GPG key, Docker Repo, install Docker and enable services
# Add repo and Install packages

echo "$password" | sudo apt update -y
echo "$password" | sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates
curl https://releases.rancher.com/install-docker/20.10.sh | sh
echo "$password" | sudo apt update -y
echo "$password" | sudo usermod -aG docker cosmote
echo "$password" | sudo usermod -aG docker root

#Download the Google Cloud public signing key for kubectl
echo "$password" | sudo curl -fsSLo /etc/apt/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg


# Create required directories
echo "$password" | sudo mkdir -p /etc/systemd/system/docker.service.d

# Create daemon json config file
echo "$password" | sudo tee /etc/docker/daemon.json <<EOF
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
echo "$password" | sudo systemctl daemon-reload
echo "$password" | sudo systemctl restart docker
echo "$password" | sudo systemctl enable docker

# Turn off swap
# The Kubernetes scheduler determines the best available node on
# which to deploy newly created pods. If memory swapping is allowed
# to occur on a host system, this can lead to performance and stability
# issues within Kubernetes.
# For this reason, Kubernetes requires that you disable swap in the host system.
# If swap is not disabled, kubelet service will not start on the masters and nodes
echo "$password" | sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
echo "$password" | sudo swapoff -a

# Turn off firewall
echo "$password" | sudo ufw disable

# Modify bridge adapter setting
# Configure sysctl.
echo "$password" | sudo modprobe overlay
echo "$password" | sudo modprobe br_netfilter

echo "$password" | sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

echo "$password" | sudo sysctl --system

# Ensure that the br_netfilter module is loaded
lsmod | grep br_netfilter
