#!/bin/bash
#This must run on master node

password=$1
##############################INSTALL kubectl##############################
#Add the Kubernetes apt repository
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Update apt package index with the new repository and install kubectl
echo "$password" | sudo apt-get update
echo "$password" | sudo apt-get install -y kubectl #kubeadm
#sudo apt-mark hold kubectl kubeadm kubelet docker docker-ce

##############################Configure kubectl on the master node with all its functions##############################

# Point the kubectl config to the previously created directory
export KUBECONFIG=~/.kube/config
# In order to run without sudo:
echo "$password" | sudo chown $(id -u):$(id -g) ~/.kube/config

# kubectl competition
kubectl completion bash | echo "$password" | sudo tee /etc/bash_completion.d/kubectl > /dev/null

# Set alias for k
# echo 'alias k=kubectl' >>~/.bashrc

# Enable the alias for auto-completion
# echo 'complete -o default -F __start_kubectl k' >>~/.bashrc

# Reload shell
#exec bash
