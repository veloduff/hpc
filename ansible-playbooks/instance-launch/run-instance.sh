#!/bin/bash

# EC2 Instance launch with Ansible

set -e

echo "EC2 Instance Ansible Setup"
echo "=========================="

# Check prerequisites
command -v ansible-playbook >/dev/null 2>&1 || { echo "Ansible required. Install: pip install ansible" >&2; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "AWS CLI required" >&2; exit 1; }

# Get user input
read -p "Instance name [my-instance]: " INSTANCE_NAME
INSTANCE_NAME=${INSTANCE_NAME:-my-instance}

read -p "AWS region [us-west-2]: " REGION
REGION=${REGION:-us-west-2}

read -p "Operating System [alinux2]: " OS_TYPE
OS_TYPE=${OS_TYPE:-alinux2}

read -p "SSH key file path [${ssh_key_path}]: " KEY_PATH
KEY_PATH=${KEY_PATH:-${ssh_key_path}}

ssh_key_name=$(basename ${KEY_PATH} .pem)

read -p "Subnet ID []: " SUBNET_ID 
SUBNET_ID=${SUBNET_ID}

read -p "Custom AMI (optional, press enter to skip): " CUSTOM_AMI
CUSTOM_AMI=${CUSTOM_AMI:-ami-xxxxxxxxx}

read -p "Post-creation script path (optional, press enter to skip): " POST_SCRIPT
POST_SCRIPT=${POST_SCRIPT:-""}

read -p "Security Group ID (optional, press enter to create new): " SECURITY_GROUP
SECURITY_GROUP=${SECURITY_GROUP:-""}

# Run Ansible playbook
ansible-playbook -i instance-inventory.ini instance-ansible.yml \
    -e "instance_name=$INSTANCE_NAME" \
    -e "region=$REGION" \
    -e "key_name=$KEY_NAME" \
    -e "subnet_id=$SUBNET_ID" \
    -e "custom_ami=$CUSTOM_AMI" \
    -e "post_script=$POST_SCRIPT" \
    -e "key_path=$KEY_PATH" \
    -e "os_type=$OS_TYPE" \
    -e "security_group=$SECURITY_GROUP" \
    -e "ansible_python_interpreter=python3" \
    -v

echo
echo "Setup complete! Check instance-access.txt for connection details."