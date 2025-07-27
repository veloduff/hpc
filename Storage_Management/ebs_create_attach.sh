#!/bin/bash
#
# AWS EBS Volume Creation and Attachment Script
# =============================================
#
# This script automates the creation and attachment of Amazon Elastic Block Store (EBS) 
# volumes to EC2 instances.
#
# - Automated EBS volume creation with configurable specifications
# - Automatically finds next available device name (/dev/sdf through /dev/sdz)
# - Support for all EBS volume types (gp2, gp3, io1, io2, st1, sc1)
# - Configurable IOPS and throughput settings
# - Extensive tagging is used with default tags
# - NVMe device detection and mapping
# - DeleteOnTermination management and **enabled by default**, can be false
#
# REQUIREMENTS:
# -------------
# - AWS CLI configured with appropriate permissions
# - EC2 permissions: CreateVolume, AttachVolume, DescribeVolumes, CreateTags
# - Running on an EC2 instance (for automatic metadata detection)
# - nvme-cli package (automatically installed if missing)
# - Sufficient EBS volume limits in the target region
#
# USAGE EXAMPLES:
# ---------------
# Usage with default options: 8GB gp3 volume, with 3000 IPOS, DeleteOnTermination="true"):
#   ./ebs_create_attach.sh
#
# Create high-performance volume:
#   ./ebs_create_attach.sh --volume-type io2 --size 100 --iops 10000
#
# Create gp3 volume with custom throughput:
#   ./ebs_create_attach.sh --volume-type gp3 --size 50 --iops 4000 --throughput 500
#
# Create volume with custom tags:
#   ./ebs_create_attach.sh --tag "Environment:Production" --tag "Project:DataAnalysis"
#
# Specify custom device and region:
#   ./ebs_create_attach.sh --device /dev/sdh --region us-east-1
#
# COMMAND LINE OPTIONS:
# ---------------------
# --region REGION              AWS region (auto-detected if on EC2)
# --az AZ                      Availability zone (auto-detected if on EC2)
# --instance-id ID             EC2 instance ID (auto-detected if on EC2)
# --volume-type TYPE           EBS volume type (gp2|gp3|io1|io2|st1|sc1)
# --size SIZE                  Volume size in GB (default: 8)
# --iops IOPS                  IOPS for gp3/io1/io2 volumes (default: 3000)
# --throughput THROUGHPUT      Throughput for gp3 volumes in MiB/s
# --device DEVICE              Device name (default: /dev/sdf, auto-increments)
# --tag "KEY:VALUE"            Add custom tag (can be used multiple times)
# --delete-on-termination BOOL Delete volume when instance terminates (default: true)
# --help                       Display usage information
#
# DeleteOnTermination is enabled by default to prevent orphaned volumes
#
set -e

# Get script filename for error messages
FILENAME=$(basename "$0")

# Function to parse tags and build AWS CLI tag format
parse_tag() {
  local key_value="$1"
  local current_tags="$2"
  
  # Check if the tag contains a colon
  if [[ "$key_value" != *:* ]]; then
    echo "Error: Tag must be in format 'key:value'" >&2
    return 1
  fi
  
  # Split at the first colon only, preserving spaces
  local key="${key_value%%:*}"
  local value="${key_value#*:}"
  
  if [[ -z "$current_tags" ]]; then
    echo "ResourceType=volume,Tags=[{Key=$key,Value=$value}]"
  else
    echo "${current_tags:0:-1},{Key=$key,Value=$value}]"
  fi
}

# Default values
VOLUME_TYPE="gp3"
SIZE="8"
DEVICE="/dev/sdf"   # starting device, will use another if not available
DELETE_ON_TERMINATION="true"
THROUGHPUT=""       # Throughput in MiB/s (only for gp3 volumes)
IOPS="3000"         # IOPS for the volume (default 3000 for gp3) set to 4000 when increasing throughput
TAGS=""

# Only use default tag if no tags are provided via command line
HAS_NAME_TAG=false

# Function to find the next available device name
find_next_device() {
  local base_device=$1
  local device_prefix=${base_device%?}  # Remove the last character
  local device_letter=${base_device: -1}  # Get the last character

  # Try device names from the provided letter through 'z'
  for (( c=$(printf "%d" "'$device_letter"); c<=$(printf "%d" "'z"); c++ )); do
    local next_letter=$(printf "\\$(printf '%03o' $c)")
    local next_device="${device_prefix}${next_letter}"

    # Check if device exists in /dev or is already attached to the instance
    FILTERS="Name=attachment.instance-id,Values=$INSTANCE_ID Name=attachment.device,Values=$next_device"
    if ! lsblk $next_device &>/dev/null && ! aws ec2 describe-volumes --region "$REGION" --filter $FILTERS --query 'Volumes[*]' --output text | grep -q .; then
      echo "$next_device"
      return 0
    fi
  done

  echo "Error: No available device names found from $base_device to ${device_prefix}z" >&2
  return 1
}

# Function to get metadata from EC2 instance metadata service
get_metadata() {
  local path=$1

  # Try IMDSv2 first
  TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null)

  if [[ -n "$TOKEN" ]]; then
    # IMDSv2 is available
    curl -s -H "X-aws-ec2-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/$path" 2>/dev/null
  else
    # Fall back to IMDSv1
    curl -s --connect-timeout 5 --retry 3 --retry-delay 1 "http://169.254.169.254/latest/meta-data/$path" 2>/dev/null
  fi
}

# Detect instance metadata
EC2_INSTANCE_ID=$(get_metadata "instance-id")
EC2_AZ=$(get_metadata "placement/availability-zone")
EC2_REGION=${EC2_AZ%?}  # Remove the last character from AZ to get region

# Log which metadata version was used
if curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" &>/dev/null; then
  echo "Using EC2 Instance Metadata Service Version 2 (IMDSv2)"
else
  echo "Using EC2 Instance Metadata Service Version 1 (IMDSv1)"
fi

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --region)
      REGION="$2"
      shift 2
      ;;
    --az)
      AZ="$2"
      shift 2
      ;;
    --volume-type)
      VOLUME_TYPE="$2"
      shift 2
      ;;
    --size)
      SIZE="$2"
      shift 2
      ;;
    --instance-id)
      INSTANCE_ID="$2"
      shift 2
      ;;
    --device)
      DEVICE="$2"
      shift 2
      ;;
    --tag)
      # Check if this is a Name tag
      if [[ "$2" == Name:* ]]; then
        HAS_NAME_TAG=true
      fi
      TAGS=$(parse_tag "$2" "$TAGS")
      shift 2
      ;;
    --delete-on-termination)
      DELETE_ON_TERMINATION="$2"
      shift 2
      ;;
    --throughput)
      THROUGHPUT="$2"
      shift 2
      ;;
    --iops)
      IOPS="$2"
      shift 2
      ;;
    --help)
      echo -n "Usage: ./attach_ebs_volume.sh [--region REGION] [--az AZ] [--instance-id INSTANCE_ID]"
      echo " [--volume-type TYPE] [--size SIZE] [--iops IOPS] [--throughput THROUGHPUT] [--device DEVICE] [--tag \"KEY:VALUE\"] [--delete-on-termination true|false]"
      exit 0
      ;;
    *)
      echo "$FILENAME: Unknown option: $1"
      exit 1
      ;;
  esac
done

# Use EC2 metadata values if not specified
REGION=${REGION:-$EC2_REGION}
AZ=${AZ:-$EC2_AZ}
INSTANCE_ID=${INSTANCE_ID:-$EC2_INSTANCE_ID}

# Check if we have the required parameters
if [[ -z "$REGION" || -z "$AZ" || -z "$INSTANCE_ID" ]]; then
  echo "Error: Could not determine required parameters automatically."
  echo "Note: When run on an EC2 instance, region, availability zone, and instance-id are auto-detected if not specified."
  exit 1
fi

# Print detected values
echo "Using the following parameters:"
echo "  Region: $REGION"
echo "  Availability Zone: $AZ"
echo "  Instance ID: $INSTANCE_ID"
echo "  Volume Type: $VOLUME_TYPE"
echo "  Size: $SIZE GB"
if [[ "$VOLUME_TYPE" == "gp3" || "$VOLUME_TYPE" == "io1" || "$VOLUME_TYPE" == "io2" ]]; then
  echo "  IOPS: $IOPS"
fi
if [[ -n "$THROUGHPUT" && "$VOLUME_TYPE" == "gp3" ]]; then
  echo "  Throughput: $THROUGHPUT MiB/s"
fi

# Find next available device if needed
if [[ "$DEVICE" == "/dev/sd"* ]]; then
  echo "Checking if device $DEVICE is available..."
  ORIGINAL_DEVICE=$DEVICE
  DEVICE=$(find_next_device "$DEVICE")
  if [[ "$DEVICE" != "$ORIGINAL_DEVICE" ]]; then
    echo "Device $ORIGINAL_DEVICE is in use, using $DEVICE instead"
  else
    echo "Device $DEVICE is available"
  fi
fi

# Start timing
START_TIME=$(date +%s)

echo "Installing nvme-cli..."
sudo dnf install --disableplugin=subscription-manager -y nvme-cli

echo "Creating ${SIZE}GB ${VOLUME_TYPE} volume in ${AZ}..."
CREATE_CMD="aws ec2 create-volume \
  --region \"$REGION\" \
  --availability-zone \"$AZ\" \
  --volume-type \"$VOLUME_TYPE\" \
  --size \"$SIZE\""

# Add IOPS parameter (for gp3, io1, io2 volumes)
if [[ "$VOLUME_TYPE" == "gp3" || "$VOLUME_TYPE" == "io1" || "$VOLUME_TYPE" == "io2" ]]; then
  CREATE_CMD="$CREATE_CMD --iops $IOPS"
  echo "Setting IOPS to $IOPS"
fi

# Add throughput parameter if specified (only for gp3 volumes)
if [[ -n "$THROUGHPUT" && "$VOLUME_TYPE" == "gp3" ]]; then
  CREATE_CMD="$CREATE_CMD --throughput $THROUGHPUT"
  echo "Setting throughput to $THROUGHPUT MiB/s"
elif [[ -n "$THROUGHPUT" && "$VOLUME_TYPE" != "gp3" ]]; then
  echo "Warning: Throughput can only be specified for gp3 volumes. Ignoring throughput setting."
fi

# Add default Name tag if no Name tag was provided
if [[ "$HAS_NAME_TAG" == "false" ]]; then
  DEFAULT_TAG="Name:File system testing"
  TAGS=$(parse_tag "$DEFAULT_TAG" "$TAGS")
fi

# Add tags if specified
if [[ -n "$TAGS" ]]; then
  CREATE_CMD="$CREATE_CMD --tag-specifications '$TAGS'"
  echo "Adding tags: $TAGS"
fi

# Execute the command and get the volume ID
VOLUME_ID=$(eval $CREATE_CMD --query 'VolumeId' --output text)

echo "Volume created: $VOLUME_ID"

echo "Waiting for volume $VOLUME_ID to become available..."
aws ec2 --region "$REGION" wait volume-available --volume-ids "$VOLUME_ID"
echo "Volume $VOLUME_ID is now available"

echo "Attaching volume $VOLUME_ID to instance $INSTANCE_ID as $DEVICE (DeleteOnTermination=$DELETE_ON_TERMINATION)..."
aws ec2 attach-volume \
  --region "$REGION" \
  --instance-id "$INSTANCE_ID" \
  --volume-id "$VOLUME_ID" \
  --device "$DEVICE"

# Set the DeleteOnTermination attribute
echo "Setting DeleteOnTermination=$DELETE_ON_TERMINATION..."
aws ec2 modify-instance-attribute \
  --region "$REGION" \
  --instance-id "$INSTANCE_ID" \
  --block-device-mappings "[{\"DeviceName\":\"$DEVICE\",\"Ebs\":{\"DeleteOnTermination\":$DELETE_ON_TERMINATION}}]"

echo "Waiting for attachment to complete..."
sleep 10

echo "Volume details:"
aws ec2 describe-volumes --region "$REGION" --volume-id "$VOLUME_ID"

echo -e "\nSearching for volume $VOLUME_ID in NVME devices:"
VOLUME_ID_SHORT=${VOLUME_ID#vol-}
sudo nvme list | grep "$VOLUME_ID_SHORT" || echo "Volume $VOLUME_ID not found in NVME devices. It may take more time to appear."

# Calculate and display elapsed time
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo -e "\nProcess completed in $ELAPSED seconds"

# Get the NVMe device name with retry
MAX_RETRIES=5
RETRY_COUNT=0
NVME_DEVICE=""

echo "Waiting for NVMe device to appear..."
while [[ -z "$NVME_DEVICE" && $RETRY_COUNT -lt $MAX_RETRIES ]]; do
  NVME_DEVICE=$(sudo nvme list | grep "$VOLUME_ID_SHORT" | awk '{print $1}')
  if [[ -z "$NVME_DEVICE" ]]; then
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "Attempt $RETRY_COUNT/$MAX_RETRIES: NVMe device not found yet, waiting 2 seconds..."
    sleep 2
  fi
done

if [[ -n "$NVME_DEVICE" ]]; then
  echo "Volume $VOLUME_ID has been created and attached to instance $INSTANCE_ID as $NVME_DEVICE"
  
  # Add Device_Name tag to the volume
  echo "Adding Device_Name tag to volume..."
  aws ec2 create-tags --region "$REGION" --resources "$VOLUME_ID" --tags Key=Device_Name,Value="$NVME_DEVICE"
  echo "Added Device_Name tag: $NVME_DEVICE"
else
  echo "Volume $VOLUME_ID has been created and attached to instance $INSTANCE_ID (NVMe device not detected after $MAX_RETRIES attempts)"
fi
