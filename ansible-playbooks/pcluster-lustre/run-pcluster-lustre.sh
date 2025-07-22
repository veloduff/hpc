#!/bin/bash

# ParallelCluster Lustre Cluster with Ansible Setup
# Exit on error (may be too strict for this)
set -e

echo "ParallelCluster Lustre Cluster Ansible Setup"
echo "============================================"

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
# def_placement_group_name=""

def_file_system_size="small"

# Get user input
read -p "Cluster name [lustre-cluster-${DATE}]: " CLUSTER_NAME
CLUSTER_NAME=${CLUSTER_NAME:-lustre-cluster-${DATE}}

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

read -p "Placement group name [${def_placement_group_name}]: " PLACEMENT_GROUP_NAME
PLACEMENT_GROUP_NAME=${PLACEMENT_GROUP_NAME:-${def_placement_group_name}}

read -p "File system size (small/medium/large/xlarge/local) [${def_file_system_size}]: " FILE_SYSTEM_SIZE
FILE_SYSTEM_SIZE=${FILE_SYSTEM_SIZE:-${def_file_system_size}}

# Set post-creation script to use wrapper
POST_SCRIPT="./pcluster-lustre-post-install-wrapper.sh"

# Display post-creation scripts being used
echo
echo "Using wrapper script: $POST_SCRIPT"
echo "Post-install wrapper script will run the following scripts:"
echo "  1. ../../Cluster_Setup/cluster_setup.sh"
echo "  2. ../../Lustre/fix_lustre_hosts_files.sh"
echo "  3. ../../Lustre/setup_lustre.sh"
echo
echo "Note: The following scripts are required dependencies and will be"
echo "      copied to the head node as part of the setup process:"
echo "      - ../../Cluster_Setup/install_pkgs.sh (required by cluster_setup.sh)"
echo "      - ../../Storage_Management/ebs_create_attach.sh (required by setup_lustre.sh)"
echo "      - ./create_lustre_components.sh (required by setup_lustre.sh)"
echo "      - ./lustre_fs_settings.sh (required by create_lustre_components.sh)"
echo

# Cluster configuration function
set_cluster_config() {
    local config_size="$1"
    
    case "$config_size" in
        "small")
            HEADNODE_INSTANCE_TYPE="m6idn.xlarge"
            MGS_INSTANCE_TYPE="m6idn.large"
            MGS_MIN_COUNT=1
            MGS_MAX_COUNT=1
            MDS_INSTANCE_TYPE="m6idn.xlarge"
            MDS_MIN_COUNT=2
            MDS_MAX_COUNT=8
            OSS_INSTANCE_TYPE="m6idn.xlarge"
            OSS_MIN_COUNT=8
            OSS_MAX_COUNT=16
            BATCH_INSTANCE_TYPE="m6idn.large"
            BATCH_MIN_COUNT=4
            BATCH_MAX_COUNT=32
            ;;
        "medium")
            HEADNODE_INSTANCE_TYPE="m6idn.xlarge"
            MGS_INSTANCE_TYPE="m6idn.xlarge"
            MGS_MIN_COUNT=1
            MGS_MAX_COUNT=1
            MDS_INSTANCE_TYPE="m6idn.xlarge"
            MDS_MIN_COUNT=4
            MDS_MAX_COUNT=8
            OSS_INSTANCE_TYPE="m6idn.xlarge"
            OSS_MIN_COUNT=20
            OSS_MAX_COUNT=40
            BATCH_INSTANCE_TYPE="m6idn.large"
            BATCH_MIN_COUNT=8
            BATCH_MAX_COUNT=128
            ;;
        "large")
            HEADNODE_INSTANCE_TYPE="m6idn.2xlarge"
            MGS_INSTANCE_TYPE="m6idn.xlarge"
            MGS_MIN_COUNT=1
            MGS_MAX_COUNT=1
            MDS_INSTANCE_TYPE="m6idn.2xlarge"
            MDS_MIN_COUNT=8
            MDS_MAX_COUNT=16
            OSS_INSTANCE_TYPE="m6idn.2xlarge"
            OSS_MIN_COUNT=40
            OSS_MAX_COUNT=128
            BATCH_INSTANCE_TYPE="m6idn.xlarge"
            BATCH_MIN_COUNT=16
            BATCH_MAX_COUNT=256
            ;;
        "xlarge")
            HEADNODE_INSTANCE_TYPE="m6idn.2xlarge"
            MGS_INSTANCE_TYPE="m6idn.xlarge"
            MGS_MIN_COUNT=1
            MGS_MAX_COUNT=1
            MDS_INSTANCE_TYPE="m6idn.2xlarge"
            MDS_MIN_COUNT=16
            MDS_MAX_COUNT=16
            OSS_INSTANCE_TYPE="m6idn.2xlarge"
            OSS_MIN_COUNT=40
            OSS_MAX_COUNT=128
            BATCH_INSTANCE_TYPE="m6idn.xlarge"
            BATCH_MIN_COUNT=16
            BATCH_MAX_COUNT=256
            ;;
        "local")
            HEADNODE_INSTANCE_TYPE="m6idn.2xlarge"
            MGS_INSTANCE_TYPE="m6idn.xlarge"
            MGS_MIN_COUNT=1
            MGS_MAX_COUNT=1
            MDS_INSTANCE_TYPE="m6idn.2xlarge"
            MDS_MIN_COUNT=16
            MDS_MAX_COUNT=32
            OSS_INSTANCE_TYPE="m6idn.2xlarge"
            OSS_MIN_COUNT=40
            OSS_MAX_COUNT=64
            BATCH_INSTANCE_TYPE="m6idn.xlarge"
            BATCH_MIN_COUNT=16
            BATCH_MAX_COUNT=256
            ;;
        *)
            echo "Error: Unknown cluster size '$config_size'"
            echo "Available sizes: small, medium, large, xlarge, local"
            exit 1
            ;;
    esac
    
    echo "Cluster configuration set to: $config_size"
}

# Set cluster configuration based on file system size
set_cluster_config "$FILE_SYSTEM_SIZE"

# Run Ansible playbook
ansible-playbook -i pcluster-lustre-inventory.ini pcluster-lustre-playbook.yml \
    -e "cluster_name=$CLUSTER_NAME" \
    -e "region=$REGION" \
    -e "key_name=$KEY_NAME" \
    -e "headnode_subnet_id=$HEADNODE_SUBNET_ID" \
    -e "compute_subnet_id=$COMPUTE_SUBNET_ID" \
    -e "custom_ami=$CUSTOM_AMI" \
    -e "post_script=$POST_SCRIPT" \
    -e "key_path=$KEY_PATH" \
    -e "os_type=$OS_TYPE" \
    -e "placement_group_name=$PLACEMENT_GROUP_NAME" \
    -e "headnode_instance_type=$HEADNODE_INSTANCE_TYPE" \
    -e "mgs_instance_type=$MGS_INSTANCE_TYPE" \
    -e "mgs_min_count=$MGS_MIN_COUNT" \
    -e "mgs_max_count=$MGS_MAX_COUNT" \
    -e "mds_instance_type=$MDS_INSTANCE_TYPE" \
    -e "mds_min_count=$MDS_MIN_COUNT" \
    -e "mds_max_count=$MDS_MAX_COUNT" \
    -e "oss_instance_type=$OSS_INSTANCE_TYPE" \
    -e "oss_min_count=$OSS_MIN_COUNT" \
    -e "oss_max_count=$OSS_MAX_COUNT" \
    -e "batch_instance_type=$BATCH_INSTANCE_TYPE" \
    -e "batch_min_count=$BATCH_MIN_COUNT" \
    -e "batch_max_count=$BATCH_MAX_COUNT" \
    -e "filesystem_size=$FILE_SYSTEM_SIZE" \
    -e "ansible_python_interpreter=python3" \
    -v

echo
echo "Setup complete! Check ansible-generated-pcluster-lustre-access.txt for connection details."
