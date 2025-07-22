#!/bin/bash

# ParallelCluster Advanced Cluster with Ansible Setup"
# Exit on error (may be too strict for this)
set -e

echo "ParallelCluster Advanced Cluster Ansible Setup"
echo "=============================================="

# Check prerequisites
command -v ansible-playbook >/dev/null 2>&1 || { echo "Ansible required. Install: pip install ansible" >&2; exit 1; }
command -v pcluster >/dev/null 2>&1 || { echo "ParallelCluster CLI required. Install: pip install aws-parallelcluster" >&2; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "AWS CLI required" >&2; exit 1; }

echo -n "Verifying AWS credentials..."
aws sts get-caller-identity >/dev/null 2>&1 || { echo " AWS credentials not configured or expired" >&2; exit 1; }
echo " verified"

DATE=$(date +%b%d-%Y%H%M)
# def_region=""
# def_key_path=""
# def_headnode_subnet_id=""
# def_compute_subnet_id=""
# def_custom_ami=""
# def_os_type=""

# Get user input
read -p "Cluster name [adv-cluster-${DATE}]: " CLUSTER_NAME
CLUSTER_NAME=${CLUSTER_NAME:-adv-cluster-${DATE}}

read -p "AWS region [${def_region}]: " REGION
REGION=${REGION:-${def_region}}

read -p "Custom AMI [${def_custom_ami}]: " CUSTOM_AMI
CUSTOM_AMI=${CUSTOM_AMI:-${def_custom_ami}}

read -p "Operating System [${def_os_type}]: " OS_TYPE
OS_TYPE=${OS_TYPE:-${def_os_type}}

read -p "SSH key file path [${def_key_path}]: " KEY_PATH
KEY_PATH=${KEY_PATH:-${def_key_path}}

# Get the key name from the KEY_PATH
def_key_name=$(basename $KEY_PATH .pem)
read -p "EC2 key pair name [${def_key_name}]: " KEY_NAME
KEY_NAME=${KEY_NAME:-${def_key_name}}

read -p "Head node subnet ID [${def_headnode_subnet_id}]: " HEADNODE_SUBNET_ID 
HEADNODE_SUBNET_ID=${HEADNODE_SUBNET_ID:-${def_headnode_subnet_id}}

read -p "Compute subnet ID [${def_compute_subnet_id}]: " COMPUTE_SUBNET_ID 
COMPUTE_SUBNET_ID=${COMPUTE_SUBNET_ID:-${def_compute_subnet_id}}

read -p "Post-creation script path (optional, press enter to skip): " POST_SCRIPT
POST_SCRIPT=${POST_SCRIPT:-""}

# Run Ansible playbook
ansible-playbook -i pcluster-adv-inventory.ini pcluster-adv-playbook.yml \
    -e "cluster_name=$CLUSTER_NAME" \
    -e "region=$REGION" \
    -e "key_name=$KEY_NAME" \
    -e "headnode_subnet_id=$HEADNODE_SUBNET_ID" \
    -e "compute_subnet_id=$COMPUTE_SUBNET_ID" \
    -e "custom_ami=$CUSTOM_AMI" \
    -e "post_script=$POST_SCRIPT" \
    -e "key_path=$KEY_PATH" \
    -e "os_type=$OS_TYPE" \
    -e "ansible_python_interpreter=python3" \
    -v

echo
echo "Setup complete! Check pcluster-adv-access.txt for connection details."