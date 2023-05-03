#!/bin/bash

##############################INSTALL KUBERNETES##############################
##############################Instal node script before rke on each node##############################
# Step 1: Make the configuration_server_script.sh file executable
echo "Install first node script to all the nodes"
echo ""
chmod +x "$(pwd)/ConfigurationFiles/configuration_server_script.sh"

# Step 2: Extract the list of IP addresses from the IP_ADDRESS file, ignoring any comments
# ip_addresses="$(grep -vE '^#|^\s*$' "$(pwd)/ConfigurationFiles/IP_ADDRESS")"
ip_addresses="$(grep -vE '^#|^\s*$' "$(pwd)/ConfigurationFiles/IP_ADDRESS" | sed 's/#.*//')"
echo "IP's of the cluster: "
echo "$ip_addresses"

# Extract the IP address of the master node from the IP_ADDRESS file
master_ip="$(awk '/master/{gsub(/#.*/, ""); print $1}' "$(pwd)/ConfigurationFiles/IP_ADDRESS")"

sudo apt install sshpass

# Prompt the user for a hostname that will be used for all IPs
read -p "Enter a username to use for all IPs of the nodes: " hostname
read -s -p "Enter a password to use for all IPs of the nodes: " password
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
            echo "File copied to $ip"
            # Make the copied file executable
            sshpass -p $password ssh -o StrictHostKeyChecking=no "$hostname@$ip" "chmod +x ~/node_script_before_rke.sh"
            # Run the copied file with sudo
            echo "$password" | sshpass -p "$password" ssh -o StrictHostKeyChecking=no "$hostname@$ip" "sudo -S ~/node_script_before_rke.sh $password"

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
"$(pwd)/ConfigurationFiles/configuration_server_script.sh" $hostname $password

echo "Running RKE installation..."
cd ConfigurationFiles
./rke up
cd ..

# Copy kubeconfig file to master node
echo "Copying kubeconfig file to master node..."
# Check if log file exists and contains "kubeconfig file copied OK"
if sshpass -p $password ssh -o StrictHostKeyChecking=no "$hostname@$master_ip" "grep 'kubeconfig file copied OK' ~/.rkeBackUp/install_log.txt"; then
    echo "kubeconfig file already copied to $master_ip"
else
    ssh "root@$master_ip" "mkdir /root/.kube"
    scp ./ConfigurationFiles/kube_config_cluster.yml "root@$master_ip:/root/.kube/config"
    if [ $? -eq 0 ]; then
        echo "kubeconfig file copied successfully to $master_ip for root user"
    else
        echo "Error copying kubeconfig file to $master_ip for root user"
    fi

    sshpass -p $password ssh -o StrictHostKeyChecking=no "$hostname@$master_ip" "mkdir ~/.kube"
    sshpass -p $password scp -o StrictHostKeyChecking=no ./ConfigurationFiles/kube_config_cluster.yml "$hostname@$master_ip:~/.kube/config"
    if [ $? -eq 0 ]; then
        sshpass -p $password ssh -o StrictHostKeyChecking=no "$hostname@$master_ip" "echo 'kubeconfig file copied OK' >> ~/.rkeBackUp/install_log.txt"
        echo "kubeconfig file copied successfully to $master_ip for user"
    else
        echo "Error copying kubeconfig file to $master_ip for user"
    fi
fi


# Copy the node_script_after_rke.sh script to the IP's home directory
if sshpass -p $password ssh -o StrictHostKeyChecking=no "$hostname@$master_ip" "grep 'config after rke OK' ~/.rkeBackUp/install_log.txt"; then
    echo "Script already executed successfully on $master_ip, skipping"
else
    sshpass -p $password scp -o StrictHostKeyChecking=no "$(pwd)/KubernetesNodeScripts/node_script_after_rke.sh" "$hostname@$master_ip:~/node_script_after_rke.sh"
    
    # Confirm that the file was copied successfully
    if [ $? -eq 0 ]; then
        echo "File copied to $master_ip"
        
        # Make the copied file executable
        sshpass -p $password ssh -o StrictHostKeyChecking=no "$hostname@$master_ip" "chmod +x ~/node_script_after_rke.sh"
        
        # Run the copied file with sudo
        sshpass ssh -o StrictHostKeyChecking=no "$hostname@$master_ip" "sudo -S ~/node_script_after_rke.sh $password"
        
        # Check if the file was executed successfully
        if [ $? -eq 0 ]; then
            echo "Script executed successfully on $master_ip"

            sshpass -p $password ssh -o StrictHostKeyChecking=no "$hostname@$master_ip" "echo 'config after rke OK' >> ~/.rkeBackUp/install_log.txt"

            sshpass -p $password ssh -o StrictHostKeyChecking=no "$hostname@$master_ip" "echo 'alias k=kubectl' >>~/.bashrc"

            sshpass -p $password ssh -o StrictHostKeyChecking=no "$hostname@$master_ip" "echo 'complete -o default -F __start_kubectl k' >>~/.bashrc"

            sshpass -p $password ssh -o StrictHostKeyChecking=no "$hostname@$master_ip" ". ~/.bashrc"

            sshpass ssh -o StrictHostKeyChecking=no "$hostname@$master_ip" "sudo -S docker run --privileged -d --restart=unless-stopped -p 80:80 -p 443:443 rancher/rancher"

            # Confirm that the Rancher was successfully installed
            if [ $? -eq 0 ]; then
                echo "Rancher installer on $master_ip"
                
                echo "Go to http://$master_ip and follow instructions to set it up"

                sshpass -p $password ssh -o StrictHostKeyChecking=no "$hostname@$master_ip" "echo 'rancher installation OK' >> ~/.rkeBackUp/install_log.txt"
            else
                echo "Rancher not installed on $master_ip"
            fi
            
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
