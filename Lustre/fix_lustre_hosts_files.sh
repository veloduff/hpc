#!/bin/bash
# Add short hostnames for hosts, and sort

# Function to process hosts and add short names
process_hosts() {
  local hosts="$1"
  local entries=()

  # Process each line
  while read -r line; do
    # Skip empty lines
    [ -z "$line" ] && continue

    # Extract IP and hostname
    ip=$(echo "$line" | awk '{print $1}')
    hostname=$(echo "$line" | awk '{print $2}')
    short_hostname=$(echo "$line" | awk '{print $3}')

    # Create short name based on hostname pattern
    if [[ "$hostname" =~ storage-mgs-.*-storage-mgs-([0-9]+) ]]; then
      # For storage MGS nodes: storage-mgs-st-storage-mgs-1 -> mgs01 (always single node)
      short_name="mgs01"
      prefix="storage-mgs"
    elif [[ "$hostname" =~ storage-mds-.*-storage-mds-([0-9]+) ]]; then
      # For storage MDS nodes: storage-mds-st-storage-mds-1 -> mds01
      num=$(echo "$hostname" | sed -E 's/.*-mds-([0-9]+).*/\1/')
      # Pad with zeros for up to 999 nodes
      short_name=$(printf "mds%03d" "$num")
      prefix="storage-mds"
    elif [[ "$hostname" =~ storage-oss-.*-storage-oss-([0-9]+) ]]; then
      # For storage OSS nodes: storage-oss-st-storage-oss-1 -> oss01
      num=$(echo "$hostname" | sed -E 's/.*-oss-([0-9]+).*/\1/')
      # Pad with zeros for up to 999 nodes
      short_name=$(printf "oss%03d" "$num")
      prefix="storage-oss"
    elif [[ "$hostname" =~ batch[0-9]+-.*-batch-([0-9]+) ]]; then
      # For batch nodes: batch01-st-batch-5 -> batch05
      num=$(echo "$hostname" | sed -E 's/.*-batch-([0-9]+).*/\1/')
      # Pad with zeros for up to 999 nodes
      short_name=$(printf "batch%03d" "$num")
      prefix="batch"
    fi

    # Add the entry to the array with prefix for sorting
    entries+=("$prefix|$short_name|$ip $hostname $short_hostname $short_name")
  done <<< "$hosts"

  # Sort the array by prefix and then by short name
  IFS=$'\n' sorted=($(sort -t'|' -k1,1 -k2,2 <<<"${entries[*]}"))
  unset IFS

  # Print the sorted entries without the sort keys
  for entry in "${sorted[@]}"; do
    #echo "${entry#*|*|}"
    entry_data="${entry#*|*|}"
    ip=$(echo "$entry_data" | awk '{print $1}')
    rest=$(echo "$entry_data" | cut -d' ' -f2-)
    printf "%-15s %s\n" "$ip" "$rest"
  done
}

echo "===== Creating new /etc/hosts file ======"

# Create temporary file for new hosts in home directory
NEW_HOSTS_FILE="$HOME/hosts.new"

# Start with original hosts file (non-cluster entries)
grep -v -E "(storage-mgs|storage-mds|storage-oss|batch)" /etc/hosts > "$NEW_HOSTS_FILE"

# Add cluster entries with short names
echo "" >> "$NEW_HOSTS_FILE"
echo "# MGS nodes" >> "$NEW_HOSTS_FILE"
echo "Processing MGS nodes..."
process_hosts "$(cat /etc/hosts | grep storage-mgs)" >> "$NEW_HOSTS_FILE"
echo "" >> "$NEW_HOSTS_FILE"
echo "# MDS nodes" >> "$NEW_HOSTS_FILE"
echo "Processing MDS nodes..."
process_hosts "$(cat /etc/hosts | grep storage-mds)" >> "$NEW_HOSTS_FILE"
echo "" >> "$NEW_HOSTS_FILE"
echo "# OSS nodes" >> "$NEW_HOSTS_FILE"
echo "Processing OSS nodes..."
process_hosts "$(cat /etc/hosts | grep storage-oss)" >> "$NEW_HOSTS_FILE"
echo "" >> "$NEW_HOSTS_FILE"
echo "# Batch nodes" >> "$NEW_HOSTS_FILE"
echo "Processing Batch nodes..."
process_hosts "$(cat /etc/hosts | grep batch)" >> "$NEW_HOSTS_FILE"

echo "===== Backing up and updating /etc/hosts ======"
# Create backup
sudo cp /etc/hosts /etc/hosts.backup.$(date +%Y%m%d-%H%M%S)
echo "Backup created: /etc/hosts.backup.$(date +%Y%m%d-%H%M%S)"

# Replace hosts file
sudo cp "$NEW_HOSTS_FILE" /etc/hosts
echo "New /etc/hosts file installed on the head node"
echo "New hosts file saved as: $NEW_HOSTS_FILE"


echo
echo "===== Creating pdsh files with hostnames from /etc/hosts ======"

echo $HOME/cluster.all
cat /etc/hosts | egrep "storage-mgs|storage-mds|storage-oss|batch" | awk '{print $NF}' > $HOME/cluster.all

for group in storage-mgs storage-mds storage-oss batch;
do
    # Create simplified filename (remove storage- prefix for file names)
    if [[ $group == storage-* ]]; then
        filename=${group#storage-}
    else
        filename=$group
    fi
    echo $HOME/cluster.${filename}
    cat /etc/hosts | grep ${group} | awk '{print $NF}' > $HOME/cluster.${filename}
done

echo
echo "===== Update WCOLL in ${HOME}/.bash_profile ======"
sed -i 's/export WCOLL=.*cluster[^\/]*/export WCOLL=$HOME\/cluster.all/' $HOME/.bash_profile
echo "Updated WCOLL in .bash_profile to use cluster.all"

echo
echo "===== Update WCOLL in /root/.bash_profile ======"
sudo sed -i 's/export WCOLL=.*cluster[^\/]*/export WCOLL=$HOME\/cluster.all/' /root/.bash_profile
echo "Updated WCOLL in /root/.bash_profile to use cluster.all"

echo
echo "===== Distributing /etc/hosts to the cluster ======"
echo "Copying new hosts file to remote nodes..."
pdcp -w ^$HOME/cluster.all $HOME/hosts.new /tmp/hosts.new
echo "Backing up /etc/hosts on remote nodes..."
pdsh -w ^$HOME/cluster.all sudo cp /etc/hosts /etc/hosts.backup.$(date +%Y%m%d-%H%M%S)
echo "Installing new hosts file on remote nodes..."
pdsh -w ^$HOME/cluster.all sudo cp /tmp/hosts.new /etc/hosts
echo "Hosts file distributed to all cluster nodes"


