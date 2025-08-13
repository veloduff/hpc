#!/bin/bash
#
# NICE DCV Instance Launch Script
# ===============================
#
# This script automates the deployment of a NICE DCV (Desktop Cloud Visualization) 
# server on AWS EC2 for remote desktop access and visualization workloads.
#
# OVERVIEW:
# ---------
# NICE DCV is a high-performance remote display protocol that enables users to 
# securely connect to graphic-intensive applications hosted on AWS. This script 
# creates a complete DCV environment with Ubuntu Desktop and automatic session management.
#
# FEATURES:
# ---------
# - Automated EC2 instance deployment with Ubuntu 22.04 LTS
# - Complete NICE DCV Server installation and configuration
# - Ubuntu Desktop environment with GDM3 display manager
# - Automatic SSH key pair generation and management
# - Security group configuration for SSH and DCV access
# - Virtual DCV session creation and auto-start on boot
# - Random password generation for secure access
# - Spot instance support for cost optimization
# - Configuration file support for customization
# - Comprehensive logging and status reporting
#
# REQUIREMENTS:
# -------------
# - AWS CLI configured with appropriate permissions
# - EC2 permissions: RunInstances, CreateKeyPair, CreateSecurityGroup, etc.
# - VPC with public subnet and internet gateway
# - Sufficient EC2 limits for m5.8xlarge instances
#
# SECURITY CONSIDERATIONS:
# ------------------------
# ️ WARNING: This script creates security groups with 0.0.0.0/0 access
# ️ For production use, restrict access to specific IP ranges
# ️ The generated SSH key is saved locally - secure it appropriately
# ️ DCV password is stored on the instance - rotate regularly
#
# INSTANCE SPECIFICATIONS:
# ------------------------
# - Operating System: Ubuntu 22.04 LTS
# - Default Instance Type: m5.8xlarge (configurable)
# - Storage: 100 GB GP3 EBS volume
# - Network: Public IP with internet access
# - Ports: 22 (SSH), 8443 (DCV HTTPS)
# - Instance Type: On-demand or Spot (configurable)
#
# USAGE:
# ------
# 1. Ensure AWS CLI is configured: aws configure
# 2. Run the script: ./launch_dcv_instance.sh
# 3. Wait for instance deployment (5-10 minutes)
# 4. Connect via web browser: https://<PUBLIC_IP>:8443
# 5. Login with username 'dcvuser' and generated password
#
# POST-DEPLOYMENT:
# ----------------
# - SSH access: ssh -i <keyfile>.pem ubuntu@<PUBLIC_IP>
# - DCV web access: https://<PUBLIC_IP>:8443
# - Password retrieval: SSH to instance, and run: sudo cat /home/ubuntu/dcv_password.txt
# - Session management: dcv list-sessions, dcv create-session
#
# CLEANUP:
# --------
# To avoid ongoing charges, terminate the instance when not needed:
# aws ec2 terminate-instances --instance-ids <INSTANCE_ID> --region <REGION>
#
# To delete created resources:
# - Terminate the EC2 instance
# - Delete the security group (if created by script)
# - Delete the SSH key pair (if created by script):
#   aws ec2 delete-key-pair --key-name <KEY_NAME> --region <REGION>
#
# CONFIGURATION:
# --------------
# The script supports configuration via ../_config/dcv.cfg file:
# - DEF_REGION: AWS region (defaults to AWS CLI configured region)
# - DEF_INSTANCE_TYPE: EC2 instance type (defaults to m5.8xlarge)
# - DEF_KEY_NAME: Existing SSH key name (creates new if not specified)
# - DEF_VPC_ID: VPC ID (uses default VPC if not specified)
# - DEF_SUBNET_ID: Subnet ID (uses first available if not specified)
# - DEF_SG_ID: Security Group ID (creates new if not specified)
# - DEF_AMI_ID: Custom AMI ID (uses latest Ubuntu 22.04 if not specified)
#
# Script variables can also be modified directly:
# - USE_SPOT_INSTANCES: Enable/disable spot instances (default: false)
# - SPOT_MAX_PRICE: Maximum spot price (empty = current market price)
# - VOLUME_SIZE: EBS volume size in GB (default: 100)
# - VOLUME_TYPE: EBS volume type (default: gp3)
#
set -e

# read variables from custom config
source ../_config/dcv.cfg 2>/dev/null || true
## Example dcv.cfg file:
#  DEF_REGION="us-west-2"
#  DEF_KEY_NAME="my-key"
#  DEF_VPC_ID="vpc-1111111"
#  DEF_SUBNET_ID="subnet-22222222"
#  DEF_SG_ID="sg-33333333"
#  DEF_INSTANCE_TYPE="g4dn.xlarge"
#  DEF_AMI_ID="ami-5555555555"

# Configuration Variables
# =======================

# EBS settings - fixed
VOLUME_SIZE=100
VOLUME_TYPE="gp3"

# Spot instance configuration
USE_SPOT_INSTANCES=false
SPOT_MAX_PRICE="" 

REGION=${DEF_REGION:-$(aws configure get region)}
echo "Using region: $REGION"

INSTANCE_TYPE=${DEF_INSTANCE_TYPE:-"m5.8xlarge"}
echo "Using instance type: $INSTANCE_TYPE"

# Git AMI ID, this should work for any region
if [[ ! $DEF_AMI_ID ]]; then
  echo "No AMI ID specified. Using latest Ubuntu 22.04 LTS AMI."
  AMI_ID=$(aws ec2 describe-images \
    --owners 099720109477 \
    --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-*-22.04-amd64-server-*" "Name=state,Values=available" \
    --query "sort_by(Images, &CreationDate)[-1].ImageId" \
    --output text \
    --region $REGION)
else
  AMI_ID=$DEF_AMI_ID
fi
echo "Using AMI $AMI_ID"

# set the ec2 key
if [[ ! $DEF_KEY_NAME ]]; then
  KEY_NAME="dcv-instance-key-$(date +%Y%m%d%H%M%S)"
  echo "Creating new key pair: $KEY_NAME in the current directory"
  aws ec2 create-key-pair --key-name $KEY_NAME --query "KeyMaterial" --output text --region $REGION > $KEY_NAME.pem
  chmod 400 $KEY_NAME.pem
  echo "Key pair created and saved to $KEY_NAME.pem"
else
  KEY_NAME=$DEF_KEY_NAME
fi
echo "Using key: $KEY_NAME"

# Get default VPC ID
VPC_ID=${DEF_VPC_ID:-$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text --region $REGION)}
echo "Using VPC: $VPC_ID"

# Get a subnet in the default VPC
SUBNET_ID=${DEF_SUBNET_ID:-$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[0].SubnetId" --output text --region $REGION)}
echo "Using subnet: $SUBNET_ID"

if [[ ! $DEF_SG_ID ]]; then
  # Create security group for DCV
  echo "Creating a new security group"
  SG_NAME="dcv-security-group-$(date +%Y%m%d%H%M%S)"
  SG_ID=$(aws ec2 create-security-group --group-name $SG_NAME --description "Security group for DCV" --vpc-id $VPC_ID --region $REGION --output text)
  echo "Created security group: $SG_NAME ($SG_ID)"
  
  # Add rules to security group
  aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 --region $REGION
  aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 8443 --cidr 0.0.0.0/0 --region $REGION
  echo "Added security group rules for SSH (22) and DCV (8443)"
else
  SG_ID=$DEF_SG_ID
fi
echo "Using security group: $SG_ID"


# User data script to install DCV, gdm3, and Ubuntu desktop
USER_DATA=$(cat <<'EOF'
#!/bin/bash
apt-get update
apt-get upgrade -y

# Install Ubuntu desktop and gdm3
apt-get install -y ubuntu-desktop gdm3

# Install required packages
apt-get install -y curl wget

# Install NICE DCV Server
cd /tmp
wget https://d1uj6qtbmh3dt5.cloudfront.net/nice-dcv-ubuntu2204-x86_64.tgz
tar -xvzf nice-dcv-ubuntu2204-x86_64.tgz
cd nice-dcv-*-x86_64
apt-get install -y ./nice-dcv-server_*.deb
apt-get install -y ./nice-dcv-web-viewer_*.deb
apt-get install -y ./nice-xdcv_*.deb

# Configure DCV for virtual sessions
systemctl enable dcvserver
systemctl start dcvserver

# Create DCV user
useradd -m dcvuser
# Generate a strong random password
DCV_PASSWORD=$(openssl rand -base64 12)
echo "dcvuser:$DCV_PASSWORD" | chpasswd
# Save password for later display
echo $DCV_PASSWORD > /home/ubuntu/dcv_password.txt
chmod 600 /home/ubuntu/dcv_password.txt

# Change the default shell to bash
chsh -s /bin/bash dcvuser

# Adding dcvuser to sudoers
echo "dcvuser ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers.d/90-cloud-init-users

# Create a virtual session
sudo -u dcvuser dcv create-session --type virtual --owner dcvuser dcvsession

# Configure automatic session creation on boot
cat > /etc/systemd/system/dcv-virtual-session.service <<EOL
[Unit]
Description=DCV Virtual Session Service
After=dcvserver.service

[Service]
Type=oneshot
User=dcvuser
ExecStart=/usr/bin/dcv create-session --type=virtual dcvsession
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOL

systemctl enable dcv-virtual-session.service

# Set a message to show how to connect
echo "DCV installation complete. Connect to https://YOUR_INSTANCE_IP:8443" > /etc/motd
EOF
)

# Build AWS CLI command
CMD="aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SG_ID \
    --subnet-id $SUBNET_ID \
    --block-device-mappings '[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":$VOLUME_SIZE,\"VolumeType\":\"$VOLUME_TYPE\"}}]' \
    --user-data '$USER_DATA' \
    --region $REGION \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=DCV-Server}]' \
    --query 'Instances[0].InstanceId' \
    --output text"

if [ "$USE_SPOT_INSTANCES" = true ]; then
    echo "Launching EC2 spot instance..."
    if [ -n "$SPOT_MAX_PRICE" ]; then
        echo "Using spot instances with max price: \$$SPOT_MAX_PRICE"
        CMD="$CMD --instance-market-options 'MarketType=spot,SpotOptions={MaxPrice=$SPOT_MAX_PRICE}'"
    else
        echo "Using spot instances at current market price"
        CMD="$CMD --instance-market-options 'MarketType=spot'"
    fi
else
    echo "Launching EC2 on-demand instance..."
fi

INSTANCE_ID=$(eval $CMD)   # Run the ec2 run-instances command

echo "Instance $INSTANCE_ID is launching..."
echo "Waiting for instance to be running..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $REGION

# Get the public IP address
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query "Reservations[0].Instances[0].PublicIpAddress" --output text --region $REGION)

echo "==========================================================="
echo "Instance $INSTANCE_ID is now running!"
if [ "$USE_SPOT_INSTANCES" = true ]; then
    echo "Instance Type: Spot Instance"
    if [ -n "$SPOT_MAX_PRICE" ]; then
        echo "Max Spot Price: \$$SPOT_MAX_PRICE"
    else
        echo "Spot Price: Current market price"
    fi
else
    echo "Instance Type: On-Demand Instance"
fi
echo "Public IP: $PUBLIC_IP"
echo "Connect to DCV: https://$PUBLIC_IP:8443"
echo "SSH: ssh -i $KEY_NAME.pem ubuntu@$PUBLIC_IP"
echo "DCV User: dcvuser"
echo "DCV Password: Check SSH connection for password"
echo "SSH into the instance and run: cat /home/ubuntu/dcv_password.txt"
echo "or run: "
echo "ssh -i $KEY_NAME.pem ubuntu@$PUBLIC_IP sudo cat dcv_password.txt"
echo "==========================================================="
echo "Check the spot price that the instance is using:"
echo "aws ec2 describe-spot-instance-requests --region $REGION --query 'SpotInstanceRequests[*].[InstanceId,SpotPrice,State]' --output table"
echo "==========================================================="
echo "Note: It may take several minutes for the instance to complete setup."
echo "You can check the system log for progress: aws ec2 get-console-output --instance-id $INSTANCE_ID --region $REGION"

