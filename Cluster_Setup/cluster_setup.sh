#!/bin/bash
#==============================================================================
# cluster_setup.sh - Comprehensive AWS ParallelCluster Setup and Validation
#==============================================================================
#
# DESCRIPTION:
#   This script provides comprehensive setup and validation for AWS ParallelCluster
#   environments, preparing clusters for HPC workloads including Lustre parallel
#   filesystems, GPFS, and high-performance computing applications.
#
# REPOSITORY LOCATION:
#   Part of the HPC infrastructure automation repository
#   Location: Cluster_Setup/cluster_setup.sh
#   Main documentation: ../README.md
#   Related scripts: install_pkgs.sh (same directory)
#
# OPERATIONS PERFORMED:
#
#   1. Package Management: Installs essential HPC tools and utilities (pdsh, nvme-cli, monitoring tools)
#   2. Cluster Communication: Sets up pdsh (Parallel Distributed Shell) for parallel command execution
#   3. Host Management: Creates and distributes cluster host files for node-to-node communication 
#   4. SSH Configuration: Enables passwordless root access across all cluster nodes
#   5. Environment Setup: Configures .bash_profile for optimal cluster operations
#   6. Storage Management: Optionally cleans up Instance Store devices for filesystem use (e.g., Lustre/GPFS)
#   7. Monitoring Tools: Installs performance monitoring and debugging utilities (htop, nmon, iperf3)
#   8. MPI Validation: Creates, compiles, and tests MPI applications for cluster verification
#   9. Slurm Testing: Submits test jobs to validate scheduler functionality
#
# USAGE:
#   ./cluster_setup.sh
#
# PREREQUISITES:
#   - Running on AWS ParallelCluster head node
#   - Slurm scheduler configured and operational
#   - Appropriate sudo permissions
#   - install_pkgs.sh script in same directory
#   - Network connectivity to all cluster nodes
#
# INTEGRATION:
#   - Called by Ansible playbooks in ../ansible-playbooks/pcluster-lustre/
#   - Used as foundation for Lustre setup (../Lustre/setup_lustre.sh)
#   - Supports GPFS deployments (../GPFS/)
#   - Enables benchmarking workflows (../Benchmarking/)
#
# CONFIGURATION:
#   Key variables can be modified below:
#   - CLEANUP_INSTANCE_STORE: Enable/disable Instance Store cleanup
#   - PACKAGE_CHECK: Enable/disable package installation
#   - REQUIRED_PKGS: List of packages to install
#
# OUTPUT:
#   - Configured cluster ready for HPC workloads
#   - MPI test results in ~/mpi-test.out
#   - Cluster host files for parallel operations
#   - Performance monitoring tools installed
#
#==============================================================================

# Exit on error
set -e

# PDSH command with SSH options to suppress warnings
export PDSH_SSH_ARGS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=~/known_hosts -o LogLevel=ERROR"

# Configuration
CLEANUP_INSTANCE_STORE=true           # Set to false to skip Instance Store cleanup
INSTALL_SCRIPT="$HOME/install_pkgs.sh"
PDSH_WCOLL_FILE="$HOME/cluster-ip-addr"

# Required packages to be installed or verify they are installed
PACKAGE_CHECK=true                    # Set to true to check and install packages
REQUIRED_PKGS="pdsh pdsh-rcmd-ssh nvme-cli screen pcp-system-tools htop strace perf psmisc tree git wget nethogs stress iperf3 nmon"

# Use dnf without subscription manager (for RHEL systems)
DNF="dnf --disableplugin=subscription-manager -q"

# Function to install AWS CLI v2
install_aws_cli() {
    if ! aws --version 2>/dev/null | grep -q "aws-cli/2"; then
        OS=$(uname -s)
        case "$OS" in
            Linux*)
                curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                unzip awscliv2.zip
                sudo ./aws/install
                ;;
            Darwin*)
                curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
                sudo installer -pkg AWSCLIV2.pkg -target /
                ;;
            *)
                echo "Unsupported OS: $OS"
                exit 1
                ;;
        esac
        echo "AWS CLI v2 installed successfully"
    else
        echo "AWS CLI v2 already installed"
    fi
}

# Function to cleanup Instance Store devices
cleanup_instance_store() {
  # Prerequisites: nvme-cli needs to be installed
  #
  echo "===== Instance Store Disk Management ====="
  
  # Get Instance Store devices from all servers
  echo "Identifying Instance Store devices..."
  local device_map=$(mktemp)
  pdsh -w ^"$PDSH_WCOLL_FILE" "sudo nvme list 2>/dev/null | grep 'Instance Storage' | awk '{print \$1}' | head -1" > "$device_map"
  
  if [[ ! -s "$device_map" ]]; then
    echo "No Instance Store devices found on compute nodes"
    rm -f "$device_map"
    return 0
  fi
  
  echo "Found Instance Store devices:"
  cat "$device_map"
  
  # Check which devices have LVM in parallel
  echo "Checking for logical volumes..."
  local lvm_check_output=$(pdsh -w ^"$PDSH_WCOLL_FILE" "sudo lsblk /dev/nvme1n1 -o TYPE 2>/dev/null | grep lvm  || echo \"LVM not found\"" | dshbak -c)
  
  echo "$lvm_check_output"
  
  # Check if any servers have LVM
  if ! echo "$lvm_check_output" | grep -q "lvm"; then
    echo "No LVM physical volumes found - all devices are clean"
    rm -f "$device_map"
    return 0
  fi
  
  echo "Processing logical volumes in parallel..."
  
  # Use all nodes from PDSH_WCOLL_FILE for parallel processing
  echo "Unmounting logical volumes (with umount -f <LV>)..."
  pdsh -w ^"$PDSH_WCOLL_FILE" 'for lv in $(sudo pvdisplay -m /dev/nvme1n1 2>/dev/null | grep "Logical volume" | awk "{print \$3}"); do sudo umount -f $lv 2>/dev/null || true; done'
  
  # Remove all logical volumes in parallel
  echo "Removing logical volumes..."
  pdsh -w ^"$PDSH_WCOLL_FILE" 'for lv in $(sudo pvdisplay -m /dev/nvme1n1 2>/dev/null | grep "Logical volume" | awk "{print \$3}"); do sudo lvremove $lv -f; done'
  
  echo "Verifying devices are clean..."
  pdsh -w ^"$PDSH_WCOLL_FILE" "lsblk /dev/nvme1n1 -o NAME,TYPE,MOUNTPOINT | grep lvm || echo 'No LVM devices'" | dshbak -c
  
  # Cleanup temp files
  rm -f "$device_map"
  
  echo "Instance Store cleanup complete"
}

echo "===== Starting Cluster Setup and Testing ====="

# Wait for system to fully initialize
wait_time=30
echo "===== Waiting $wait_time seconds for system initialization ====="
sleep $wait_time

# Install AWS CLI v2 if needed
install_aws_cli 

# Install packages on head node
if [[ "$PACKAGE_CHECK" == "true" ]]; then
  echo "===== Installing packages on head node ====="
  $INSTALL_SCRIPT $REQUIRED_PKGS
else
  echo "===== Package installation disabled (PACKAGE_CHECK=false) ====="
  echo "Note: Packages will not be checked or installed on the head node"
fi 

# Create a file with all cluster node IP addresses
echo "===== Creating cluster hosts file ====="
export USER=$(whoami)
export cluster_hosts_file=$PDSH_WCOLL_FILE
export GREP_STRING='NodeAddr=[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'
# Extract node IP addresses from Slurm configuration
scontrol show node | grep -E "$GREP_STRING" | awk '{print $1}' | cut -f2 -d'=' > $cluster_hosts_file

# Copy the cluster hosts file to root's home directory for root-level pdsh commands
echo "===== Copying cluster hosts file to /root/ ====="
sudo cp $cluster_hosts_file /root/$(basename $cluster_hosts_file)

# Set up user's .bash_profile with cluster management settings
echo "===== Setting up .bash_profile ====="
cat > $HOME/.bash_profile << 'EOF'
# .bash_profile

if [ -f $HOME/.bashrc ]; then
        . $HOME/.bashrc
fi

# set user - could be different, depending on the OS
export USER=$(whoami)

# Set vi as the editor
export EDITOR=vi
set -o vi

# Update all (across shells) history files immediately
export PROMPT_COMMAND='history -a;history -r'

# Put hostname and path in the terminal title
#  Use # for root

if [ $(whoami) = "root" ]
then
 PROMPT='[%n@%m] %~ # '
else
 PROMPT='[%n@%m] %~ $ '
fi

# fix warning for ssh known_hosts file
export PDSH_SSH_ARGS_APPEND="-o StrictHostKeyChecking=no -o UserKnownHostsFile=$HOME/known_hosts"
alias ssh='ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=$HOME/known_hosts'

# set remote command for pdsh to ssh
export PDSH_RCMD_TYPE=ssh

# set hosts for pdsh
export WCOLL=$HOME/cluster-ip-addr

# updated path
export PATH=$PATH:$HOME/bin:/usr/lpp/mmfs/bin
EOF

# Source the new .bash_profile to apply changes to current session
source $HOME/.bash_profile

# Create a script to enable root SSH access and copy .bash_profile to root
echo "===== Creating root SSH and .bash_profile setup script ====="
cat > $HOME/setup_ssh.sh << 'EOF'
#!/bin/bash
function enable_root_ssh {
  USER=$(logname || echo "ec2-user")
  echo "${0}: setting up root ssh"

  # Generate SSH key for root if it doesn't exist
  [ -f /home/$USER/.ssh/root_ed25519 ] || ssh-keygen -t ed25519 -f /home/$USER/.ssh/root_ed25519 -N ""

  # Copy SSH keys to root's .ssh directory
  if ! [ -f "/root/.ssh/id_ed25519" ]; then
    mkdir -p /root/.ssh
    cp /home/$USER/.ssh/root_ed25519 /root/.ssh/id_ed25519
    cp /home/$USER/.ssh/root_ed25519.pub /root/.ssh/id_ed25519.pub
    cat /home/$USER/.ssh/root_ed25519.pub >> /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/id_ed25519
    chmod 644 /root/.ssh/id_ed25519.pub
    chmod 600 /root/.ssh/authorized_keys
  fi

  # Copy user's .bash_profile to root
  cp /home/$USER/.bash_profile /root/.bash_profile

  # Enable root SSH login in sshd_config
  sed -i.bak 's/PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
  sed -i.bak2 's/#PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
  systemctl restart sshd
}
enable_root_ssh
EOF

chmod 755 $HOME/setup_ssh.sh

# Run the SSH setup script on the head node
echo "===== Setting up root SSH and .bash_profile on HeadNode ====="
sudo $HOME/setup_ssh.sh

# Run the SSH setup script on all compute nodes
echo "===== Setting up root SSH and .bash_profile on compute nodes ====="
pdsh -w ^"$PDSH_WCOLL_FILE" sudo $HOME/setup_ssh.sh | dshbak -c

# Test pdsh functionality as root
echo "===== Testing pdsh as root with date command ====="
sudo /bin/su - -c "pdsh -w ^$PDSH_WCOLL_FILE date"

# Install packages on cluster nodes
if [[ "$PACKAGE_CHECK" == "true" ]]; then
  echo "===== Installing packages on cluster nodes ====="
  pdsh -w ^"$PDSH_WCOLL_FILE" $INSTALL_SCRIPT $REQUIRED_PKGS | dshbak -c
else
  echo "===== Package installation disabled (PACKAGE_CHECK=false) ====="
  echo "Note: Packages will not be checked or installed on cluster nodes"
fi

# Cleanup Instance Store devices if enabled
if [[ "$CLEANUP_INSTANCE_STORE" == "true" ]]; then
  cleanup_instance_store
else
  echo "===== Skipping Instance Store cleanup (disabled) ====="
fi

# Build a consolidated /etc/hosts file with all node information
echo "===== Building /etc/hosts file ====="

# Backup existing hosts files
echo "  === Backing up /etc/hosts file to /etc/hosts.bak (head node and cluster nodes) ==="
sudo cp /etc/hosts /etc/hosts.bak
pdsh -w ^"$PDSH_WCOLL_FILE" sudo cp /etc/hosts /etc/hosts.bak

# Add cluster nodes to hosts file on HeadNode
echo "  === Updating /etc/hosts file on head node (appends cluster hostnames to /etc/hosts on head node) ===" 
sudo /bin/su - -c "pdsh -w ^$PDSH_WCOLL_FILE cat /etc/hosts | grep -v localhost | cut -f2 -d':' | sed 's/^ //g' >> /etc/hosts"

# Copy the consolidated hosts file to all compute nodes
echo "  === Distributing /etc/hosts file from head node to cluster nodes ==="
sudo /bin/su - -c "pdcp -w ^$PDSH_WCOLL_FILE /etc/hosts /etc/hosts"

# Create a simple MPI test program to verify cluster functionality
echo "===== Creating MPI test program =====" 
cat > $HOME/mpi-test.c << 'EOF'
#include <mpi.h>
#include <stdio.h>
#include <stddef.h>

int main(int argc, char** argv) {
  MPI_Init(NULL, NULL);

  // Get the number of processes
  int world_size;
  MPI_Comm_size(MPI_COMM_WORLD, &world_size);

  // Get the rank of the process
  int world_rank;
  MPI_Comm_rank(MPI_COMM_WORLD, &world_rank);

  // Get the name of the processor
  char processor_name[MPI_MAX_PROCESSOR_NAME];
  int name_len;
  MPI_Get_processor_name(processor_name, &name_len);

  // Print off a hello world message
  printf("Hello world from processor %s, rank %d out of %d processors\n",
         processor_name, world_rank, world_size);

  // Finalize the MPI environment. No more MPI calls can be made after this
  MPI_Finalize();
}
EOF

# Compile the MPI test program
echo "===== Compiling MPI test program ====="
module load openmpi
mpicc -o $HOME/mpi-test $HOME/mpi-test.c

# Set partition and determine node count
PARTITION="batch01"
NODE_COUNT=$(sinfo -h -p $PARTITION -o "%D %t" | grep -v idle~ | head -1 | awk '{print $1}')

# Fallback to first available partition if batch01 doesn't exist
if [ -z "$NODE_COUNT" ]; then
  PARTITION=$(sinfo -h -o "%R" | head -1)
  NODE_COUNT=$(sinfo -h -p $PARTITION -o "%D %t" | grep -v idle~ | head -1 | awk '{print $1}')
fi

# Default to 1 node if still no count found
NODE_COUNT=${NODE_COUNT:-1}

# WARNING
# The PMIx `--mpi=pmix_v5` argument may need to be set when calling `srun`. PMIx stands for Process 
# Management Interface for Exascale (https://docs.open-mpi.org/en/v5.0.x/launching-apps/pmix-and-prrte.html).
# It's a standard and a package used by Open MPI to manage, communicate, and 
# coordinate MPI processes with a back-end runtime system, especially in large-scale, exascale 
# environments. Slurm specific info for PMIx: https://slurm.schedmd.com/mpi_guide.html#pmix

# Create a Slurm batch script for MPI testing
cat > $HOME/mpi-test-batch.sh << 'EOF'
#!/bin/bash
#SBATCH -J mpi-test 
#SBATCH -o mpi-test.out
#SBATCH -e mpi-test.err
#SBATCH --exclusive
####SBATCH --nodes=4
#SBATCH --ntasks-per-node=1

## optionally load Intel MPI:
# module purge
# module load intelmpi
module list

srun --mpi=pmix_v5 $HOME/mpi-test
EOF

# Make the batch script executable
chmod +x $HOME/mpi-test-batch.sh

# Display available Slurm partitions
echo "===== Available Slurm partitions ====="
sinfo

# Submit the MPI test job to the Slurm scheduler
echo "===== Submitting MPI test job ====="
echo "Using partition: $PARTITION"
if [ "$NODE_COUNT" -gt 0 ]; then
  sbatch -p $PARTITION --nodes=${NODE_COUNT} $HOME/mpi-test-batch.sh
else
  echo "Skipping MPI test job submission, no batch or compute nodes available"
fi

# Check the status of the submitted job
echo "===== Checking job status ====="
squeue -l

echo "===== Cluster setup and testing complete ====="
echo "Wait for the job to complete, then check ~/mpi-test.out for results"
echo "You can monitor job status with: squeue -l"

# Remind user to source .bash_profile
echo "Source .bash_profile to update environment variables"
echo "Run this:  source ~/.bash_profile"
