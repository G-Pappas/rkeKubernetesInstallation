#!/bin/bash

#######################COPY THE SSH KEYS OF ALL THE WORKERS AND THE MASTER NODES####################################
#Prompt for entering the password of the nodes
read -s -p "Enter the password of the nodes: " PASSWORD

# Check if the input file exists
# if [ -f "$input_file" ]; then
#   echo "Input file found: $input_file"
# else
#   echo "Input file not found: $input_file"
#   exit 1
# fi

# Check if ~/.ssh/ directory exists
if [ ! -d ~/.ssh ]; then
  # If it doesn't exist, create it with the correct permissions
  mkdir -m 700 ~/.ssh
fi

# Read list of IP addresses from a text file
while read -r LINE; do
  # Ignore blank lines
  if [ -z "$LINE" ]; then
    continue
  fi

  # Extract the IP address from the line
  IP_ADDRESS=$(echo "$LINE" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')



  # Ignore lines that don't contain a valid IP address
  if [ -z "$IP_ADDRESS" ]; then
    continue
  fi

  # Validate the IP address format
  if ! echo "$IP_ADDRESS" | grep -qE '^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'; then
    echo "Invalid IP address format: $IP_ADDRESS"
    continue
  fi

  # Remove the IP address and anything after a "#" character
  LINE=${LINE%%$IP_ADDRESS*}
  LINE=$(echo "$LINE" | sed 's/#.*$//')

  # Check if the IP address already exists in the .pub file
  PUB_FILE=$(ls -1 ~/.ssh/*.pub 2>/dev/null | head -n 1)
  if [ -n "$PUB_FILE" ]; then
    grep -q "$IP_ADDRESS" "$PUB_FILE"
    if [ $? -eq 0 ]; then
      # If the IP address exists in the .pub file, skip adding it again
      echo "IP address $IP_ADDRESS already exists in $PUB_FILE, skipping..."
      continue
    fi
  fi

  if [ -n "$PUB_FILE" ]; then
    # If a .pub file exists in the ~/.ssh/ directory, use ssh-copy-id to copy the public key to the remote server with the found name
    sshpass -p $PASSWORD ssh-copy-id  -o StrictHostKeyChecking=no -i "$PUB_FILE" root@$IP_ADDRESS
  else
    # If a .pub file doesn't exist in the ~/.ssh/ directory, create a new key with the default name
    ssh-keygen -b 4096 -t rsa -f ~/.ssh/id_rsa -q -N ""

    # Use ssh-copy-id to copy the new public key to the remote server with the default name
    sshpass -p $PASSWORD ssh-copy-id  -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa.pub root@$IP_ADDRESS
  fi

done < ./ConfigurationFiles/IP_ADDRESS

#############################INSTALL THE RKE ON THE SERVER############################################
# Check if rke executable file exists, if not download it
if [ ! -f ./ConfigurationFiles/rke ]; then
  echo "rke executable file not found, downloading..."
  cd ConfigurationFiles
  wget https://github.com/rancher/rke/releases/download/v1.4.4/rke_linux-amd64 -O rke
  chmod +x rke
  cd ..
else
  echo "rke executable file already exists"
fi


#########################ADD IP AND HOSTNAMES TO THE CLUSTER.YML FILE##################################

# Read the IP_ADDRESS file line by line
while IFS= read -r line; do
  # Check if the line is empty or starts with a comment character #
  if [[ -z "$line" || "$line" == \#* ]]; then
    continue
  fi

  # Extract the IP address and hostname from the line
  ip_address=$(echo "$line" | cut -d ' ' -f 1)
  hostname=$(echo "$line" | cut -d ' ' -f 2 | tr -d '#')

  # Check if the hostname is empty
  if [[ -z "$hostname" ]]; then
    echo "Warning: No hostname found for IP address $ip_address. Skipping..."
    continue
  fi

  # Validate the IP address format
  if ! echo "$ip_address" | grep -qE '^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'; then
    echo "Invalid IP address format: $ip_address"
    continue
  fi

  # Determine the role based on the hostname
  if [[ "$hostname" == *"master"* ]]; then
    role="- controlplane\n      - etcd"
  else
    role="- worker"
  fi

  # Create a new node entry
  new_node_entry="  - address: $ip_address\n    user: root\n    hostname_override: $hostname\n    role:\n      $role\n    docker_socket: /var/run/docker.sock"

  # Check if the node already exists in the cluster.yml file
  if grep -q "address: $ip_address" ./ConfigurationFiles/cluster.yml; then
    # Remove the old node entry
    sed -i "/address: $ip_address/,/docker_socket: \/var\/run\/docker.sock/d" ./ConfigurationFiles/cluster.yml
  fi

  # Add the new node entry to the nodes section of the cluster.yml file
  sed -i '/^nodes:/a \'"$new_node_entry"'' ./ConfigurationFiles/cluster.yml

done < ./ConfigurationFiles/IP_ADDRESS