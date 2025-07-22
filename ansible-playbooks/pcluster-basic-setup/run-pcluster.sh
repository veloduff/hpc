#!/bin/bash

# ParallelCluster creation with Ansible

set -e

echo "ParallelCluster Ansible Setup"
echo "============================="

# Check prerequisites
command -v ansible-playbook >/dev/null 2>&1 || { echo "Ansible required. Install: pip install ansible" >&2; exit 1; }
command -v pcluster >/dev/null 2>&1 || { echo "ParallelCluster CLI required. Install: pip install aws-parallelcluster" >&2; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "AWS CLI required" >&2; exit 1; }


# Get user input
read -p "Cluster name [my-hpc-cluster]: " CLUSTER_NAME
CLUSTER_NAME=${CLUSTER_NAME:-my-hpc-cluster}

read -p "AWS region [us-west-2]: " REGION
REGION=${REGION:-us-west-2}

read -p "Operating System [rhel8]: " OS_TYPE
OS_TYPE=${OS_TYPE:-rhel8}

read -p "SSH key file path [${ssh_key_path}]: " KEY_PATH
KEY_PATH=${KEY_PATH:-${ssh_key_path}}

ssh_key_name=$(basename ${KEY_PATH} .pem)

read -p "Subnet ID [subnet-02e39a2073c9bc988]: " SUBNET_ID 
SUBNET_ID=${SUBNET_ID:-subnet-02e39a2073c9bc988}

read -p "Custom AMI (optional, press enter to skip): " CUSTOM_AMI
CUSTOM_AMI=${CUSTOM_AMI:-ami-xxxxxxxxx}

read -p "Post-creation script path (optional, press enter to skip): " POST_SCRIPT
POST_SCRIPT=${POST_SCRIPT:-""}


# Run Ansible playbook
ansible-playbook -i pcluster-inventory.ini pcluster-ansible.yml \
    -e "cluster_name=$CLUSTER_NAME" \
    -e "region=$REGION" \
    -e "key_name=$KEY_NAME" \
    -e "subnet_id=$SUBNET_ID" \
    -e "custom_ami=$CUSTOM_AMI" \
    -e "post_script=$POST_SCRIPT" \
    -e "key_path=$KEY_PATH" \
    -e "os_type=$OS_TYPE" \
    -e "ansible_python_interpreter=python3" \
    -v

echo
echo "Setup complete! Check cluster-access.txt for connection details."