#!/bin/bash

##############################INSTALL KUBERNETES##############################

##############################Instal node script before rke on each node##############################
# Step 1: Make the configuration_server_script.sh file executable
echo "Install first node script to all the nodes"
echo ""
chmod +x "$(pwd)/ConfigurationFiles/configuration_server_script.sh"

# Step 2: Extract the list of IP addresses from the IP_ADDRESS file, ignoring any comments
ip_addresses="$(grep -vE '^#|^\s*$' "$(pwd)/ConfigurationFiles/IP_ADDRESS")"
echo "$ip_addresses"
# Extract the IP address of the master node from the IP_ADDRESS file
master_ip=$(grep -E '^[^#]*\smaster\s*#' "$(pwd)/ConfigurationFiles/IP_ADDRESS" | awk '{print $1}')

sudo apt install sshpass

# Prompt the user for a hostname that will be used for all IPs
read -p "Enter a username to use for all IPs: " hostname
read -s -p "Enter a password to use for all IPs: " password
echo ""

# Loop through the IP addresses and copy the node_script_before_rke.sh script to each IP's home directory
for ip in $ip_addresses
do
    sshpass -p $password ssh -o StrictHostKeyChecking=no "$hostname@$ip" "mkdir .rkeBackUp"
    sshpass -p $password ssh -o StrictHostKeyChecking=no "$hostname@$ip" "touch .rkeBackUp/install_log.txt"
    # Check if the file was executed successfully before
    if sshpass -p $password ssh -o StrictHostKeyChecking=no "$hostname@$ip" "grep 'config before rke OK' ~/.rkeBackUp/install_log.txt"; then
        echo "Script already executed successfully on $ip. Skipping installation."
    else
        # Copy the node_script_before_rke.sh script to the IP's home directory
        sshpass -p $password scp -o StrictHostKeyChecking=no "$(pwd)/KubernetesNodeScripts/node_script_before_rke.sh" "$hostname@$ip:~/node_script_before_rke.sh"
        # Confirm that the file was copied successfully
        if [ $? -eq 0 ]; then
            echo "File copied to @$ip"
            # Make the copied file executable
            sshpass -p $password ssh -o StrictHostKeyChecking=no "$hostname@$ip" "chmod +x ~/node_script_before_rke.sh"
            # Run the copied file with sudo
            sshpass -p $password ssh -o StrictHostKeyChecking=no "$hostname@$ip" "echo $password | sudo -S ~/node_script_before_rke.sh"
            # Check if the file was executed successfully
            if [ $? -eq 0 ]; then
                echo "Script executed successfully on $ip"
                
                # Create log file and write success message
                sshpass -p $password ssh -o StrictHostKeyChecking=no "$hostname@$ip" "echo 'config before rke OK' >> ~/.rkeBackUp/install_log.txt"
                
                # Delete the copied file if it was executed successfully
                sshpass -p $password ssh -o StrictHostKeyChecking=no "$hostname@$ip" "rm -f ~/node_script_before_rke.sh"
                
                # Confirm that the file was deleted successfully
                if [ $? -eq 0 ]; then
                    echo "File deleted on $ip"
                else
                    echo "Error deleting file on $ip"
                fi
            else
                echo "Error executing script on $ip"
            fi
        else
            echo "Error copying file to $ip"
        fi
    fi
done


##############################Instal node script before rke on each node##############################
echo "Install separate machine script to add IP's to cluster.yml and .ssh"
echo ""
."$(pwd)/ConfigurationFiles/configuration_server_script.sh"

echo "Running RKE installation..."
."$(pwd)/ConfigurationFiles/rke up"

# Copy kubeconfig file to master node
echo "Copying kubeconfig file to master node..."

# Check if log file exists and contains "kubeconfig file copied OK"
if sshpass -p $password ssh -o StrictHostKeyChecking=no "$hostname@$ip" "grep 'kubeconfig file copied OK' ~/.rkeBackUp/install_log.txt"; then
    echo "kubeconfig file already copied to $master_ip"
else
    sshpass -p $password ssh -o StrictHostKeyChecking=no "$hostname@$master_ip" "mkdir ~/.kube"
    sshpass -p $password scp -o StrictHostKeyChecking=no ./ConfigurationFiles/kube_config_cluster.yml "root@$master_ip:~/.kube/config"
    if [ $? -eq 0 ]; then
        sshpass -p $password ssh -o StrictHostKeyChecking=no "$hostname@$master_ip" "echo 'kubeconfig file copied OK' >> ~/.rkeBackUp/install_log.txt"
        echo "kubeconfig file copied successfully to $master_ip"
    else
        echo "Error copying kubeconfig file to $master_ip"
    fi
fi


# Copy the node_script_after_rke.sh script to the IP's home directory
if sshpass -p $password ssh -o StrictHostKeyChecking=no "$hostname@$master_ip" "grep 'config before rke OK' ~/.rkeBackUp/install_log.txt"; then
    echo "Script already executed successfully on $master_ip, skipping"
else
    sshpass -p $password scp -o StrictHostKeyChecking=no "$(pwd)/KubernetesNodeScripts/node_script_after_rke.sh" "$hostname@$master_ip:~/node_script_after_rke.sh"
    
    # Confirm that the file was copied successfully
    if [ $? -eq 0 ]; then
        echo "File copied to $master_ip"
        
        # Make the copied file executable
        sshpass -p $password ssh -o StrictHostKeyChecking=no "$hostname@$master_ip" "chmod +x ~/node_script_after_rke.sh"
        
        # Run the copied file with sudo
        sshpass -p $password ssh -o StrictHostKeyChecking=no "$hostname@$master_ip" "echo $password | sudo -S ~/node_script_after_rke.sh"
        
        # Check if the file was executed successfully
        if [ $? -eq 0 ]; then
            echo "Script executed successfully on $master_ip"

            sshpass -p $password ssh -o StrictHostKeyChecking=no "$hostname@$master_ip" "echo 'config after rke OK' >> ~/.rkeBackUp/install_log.txt"
            
            # Delete the copied file if it was executed successfully
            sshpass -p $password ssh -o StrictHostKeyChecking=no "$hostname@$master_ip" "rm -f ~/node_script_after_rke.sh"
            
            # Confirm that the file was deleted successfully
            if [ $? -eq 0 ]; then
                echo "File deleted on $master_ip"
            else
                echo "Error deleting file on $master_ip"
            fi
        else
            echo "Error executing script on $master_ip"
        fi
    else
        echo "Error copying file to $master_ip"
    fi
fi
