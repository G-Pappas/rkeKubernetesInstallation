# Automated Kubernetes Installation with RKE

This project provides an automated way to install Kubernetes using Rancher Kubernetes Engine (RKE) and bash scripting. The installation is done on a cluster of nodes running Ubuntu Server 22.0.4.

## Description

The project consists of a main script that installs all the prerequisites for installing Kubernetes with RKE. It also ensures that the installing machine has root access to every node. The IP addresses of the nodes are extracted from a text file named `IP_ADDRESS` in the `ConfigurationFiles` folder. This file must be edited according to the following format: `"IP #Name_of_the_node"` (use one word and only the master node must contain the word "master" in the node name). Then the user is prompted to type the username and password of the nodes. It assumes that the same username and password are used for all the nodes. Using all the above information, the pre-installation is performed on every node.

The script creates a log file under the directory `~/.rkeBackUp` that contains information on which scripts are installed successfully on the node. This information is also used by the script to avoid re-installing any already installed software or setting. This file must not be removed, deleted, or edited.

After the cluster is initialized, the script installs `kubectl` with any requirements it needs. Autocomplete for tab and alias for "k" shortcut is also set.

## Procedure

To use this script, follow these steps:

1. Clone the repository on a Linux machine that you will use to configure the cluster (not a node of the cluster).
2. Make the `kubernetes-installation.sh` script executable (`chmod +x kubernetes-installation.sh`).
3. Edit the `IP_ADDRESS` file located in `~/rkeKubernetesInstallation/ConfigurationFiles` to specify the IP addresses and node names.
4. From the `~/rkeKubernetesInstallation` directory, execute the `kubernetes-installation.sh` script (`./kubernetes-installation.sh`).

## Editing the cluster

If you wish to add nodes to the cluster, you need to add the IPs on the `IP_ADDRESS` file and re-run the script.

If you need to remove a node from the cluster, you must remove it from the `cluster.yml` file in `~/rkeKubernetesInstallation/ConfigurationFiles` path and from `IP_ADDRESS` file.

## Notes

- You must not rename the nodes or change the IP of an already initialized node.
- In order to change the name or IP address of an already existing node, you must first remove it from the `cluster.yml` file. This is because we must not have two nodes with the same IP or node name.

Please keep in mind these notes in order to maintain the cluster's integrity and avoid any conflicts.
