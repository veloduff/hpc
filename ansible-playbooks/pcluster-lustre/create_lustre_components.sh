#!/bin/bash
#==============================================================================
# create_lustre_components.sh - Create individual Lustre components (MDT/OST)
#==============================================================================
#
# DESCRIPTION:
#   Creates EBS volumes, ZFS pools, and Lustre components for a single server
#   Determines component indices based on hostname and component type
#
# USAGE:
#   ./create_lustre_components.sh --fsname <filesystem_name> [--global-pool-idx <index>] [--mgs-node <hostname>]
#   
#   --fsname: Lustre filesystem name
#   --global-pool-idx: Global pool index offset (default: 0)
#   --mgs-node: MGS node hostname (default: mgs01)
#   Component type is auto-detected from hostname:
#   - OSS servers (containing 'oss'): creates OST components
#   - MDS servers (containing 'mds'): creates MDT components
#
# EXAMPLE:
#   ./create_lustre_components.sh --fsname scratch --global-pool-idx 10 --mgs-node mgs001
#==============================================================================

set -e

# Get script filename for error messages
FILENAME=$(basename "$0")

#==============================================================================
# Multiple file system section
#==============================================================================
# Load filesystem settings
SETTINGS_FILE="$(dirname "$0")/lustre_fs_settings.sh"
if [[ -f "$SETTINGS_FILE" ]]; then
    source "$SETTINGS_FILE"
    # Default to small configuration if no --fs-type specified
    fs_settings "small"
else
    echo "Error: Settings file $SETTINGS_FILE not found"
    exit 1
fi

# ZFS pool/dataset indices (must be unique across all file systems)
# For multiple file systems, change these to avoid conflicts
MDT_POOL_START_INDEX=0             # Starting index for MDT ZFS pools
OST_POOL_START_INDEX=0             # Starting index for OST ZFS pools
#
#==============================================================================



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

# Initialize variables
FS_NAME=""
GLOBAL_POOL_IDX=0
HOSTNAME=$(hostname)
EBS_COMM="$HOME/ebs_create_attach.sh"
MGS_NODE="mgs01"
EXTEND_EXISTING_FS=false
FIX_FAILED_CREATE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --fsname)
      FS_NAME="$2"
      shift 2
      ;;
    --global-pool-idx)
      GLOBAL_POOL_IDX="$2"
      shift 2
      ;;
    --mgs-node)
      MGS_NODE="$2"
      shift 2
      ;;
    --extend-existing-fs)
      EXTEND_EXISTING_FS=true
      shift
      ;;
    --fix-failed-create)
      FIX_FAILED_CREATE=true
      shift
      ;;
    --mdt-pool-idx)
      MDT_POOL_START_INDEX="$2"
      shift 2
      ;;
    --ost-pool-idx)
      OST_POOL_START_INDEX="$2"
      shift 2
      ;;
    --use-local-disks)
      MDT_USE_LOCAL=true
      OST_USE_LOCAL=true
      shift
      ;;
    --fs-type)
      fs_settings "$2"
      shift 2
      ;;
    --help)
      echo "Usage: $0 --fsname <filesystem_name> [--global-pool-idx <index>] [--mgs-node <hostname>] [--extend-existing-fs] [--fix-failed-create] [--mdt-pool-idx <index>] [--ost-pool-idx <index>] [--use-local-disks] [--fs-type <type>]"
      echo "  --fsname: Lustre filesystem name"
      echo "  --global-pool-idx: Global pool index offset (default: 0)"
      echo "  --mgs-node: MGS node hostname (default: mgs01)"
      echo "  --extend-existing-fs: Allow adding components to existing file system"
      echo "  --fix-failed-create: Continue if ZFS pool exists (for fixing failed creation)"
      echo "  --mdt-pool-idx: Starting index for MDT ZFS pools (overrides default)"
      echo "  --ost-pool-idx: Starting index for OST ZFS pools (overrides default)"
      echo "  --use-local-disks: Use local NVMe storage for both MDT and OST components"
      echo "  --fs-type: File system performance type (small, medium, large, xlarge, local)"
      echo "Component type is auto-detected from hostname:"
      echo "  - OSS servers (containing 'oss'): creates OST components"
      echo "  - MDS servers (containing 'mds'): creates MDT components"
      echo "  - MGS servers (containing 'mgs'): creates MGT components"
      echo "Example: $0 --fsname scratch --global-pool-idx 10 --mgs-node mgs001 --extend-existing-fs"
      echo "Example: $0 --fsname scratch --fix-failed-create"
      exit 0
      ;;
    *)
      echo "$FILENAME: Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Validate required arguments
if [[ -z "$FS_NAME" ]]; then
  echo "Error: --fsname is required"
  echo "Use --help for usage information"
  exit 1
fi

# Auto-detect component type from hostname
if [[ "$HOSTNAME" == *"oss"* ]]; then
  COMPONENT_TYPE="ost"
elif [[ "$HOSTNAME" == *"mds"* ]]; then
  COMPONENT_TYPE="mdt"
elif [[ "$HOSTNAME" == *"mgs"* ]]; then
  COMPONENT_TYPE="mgt"
else
  echo "Error: Cannot determine component type from hostname '$HOSTNAME'"
  echo "Hostname must contain 'oss' for OST servers, 'mds' for MDT servers, or 'mgs' for MGT servers"
  exit 1
fi

# Check for existing Lustre file system
echo "Checking for existing Lustre components..."
if sudo lctl dl -t 2>/dev/null | grep -q "${FS_NAME}"; then
  if [[ "$EXTEND_EXISTING_FS" != "true" && "$FIX_FAILED_CREATE" != "true" ]]; then
    echo "Error: Lustre file system '${FS_NAME}' already exists on this node"
    echo "Use --extend-existing-fs flag to add components to existing file system"
    echo "Or use --fix-failed-create flag to fix failed filesystem creation"
    exit 1
  elif [[ "$EXTEND_EXISTING_FS" == "true" ]]; then
    echo "Extending existing Lustre file system '${FS_NAME}'"
  elif [[ "$FIX_FAILED_CREATE" == "true" ]]; then
    echo "Fixing failed creation of Lustre file system '${FS_NAME}'"
  fi
else
  echo "No existing Lustre file system '${FS_NAME}' found - creating new components"
fi



# Warning message for component count changes
COMPONENT_WARNING="COMPONENTS_PER_SERVER changed from %d to 1 for local disk usage"

# Component-specific settings
if [[ "$COMPONENT_TYPE" == "mgt" ]]; then
  COMPONENTS_PER_SERVER=1
  VOLUME_SIZE=$MGT_SIZE
  VOLUME_TYPE=$MGT_VOLUME_TYPE
  THROUGHPUT=$MGT_THROUGHPUT
  IOPS=$MGT_IOPS
  POOL_START_INDEX=0
elif [[ "$COMPONENT_TYPE" == "mdt" ]]; then
  COMPONENTS_PER_SERVER=$MDTS_PER_MDS
  if [[ "$MDT_USE_LOCAL" == "true" && $COMPONENTS_PER_SERVER -gt 1 ]]; then
    printf "Warning: MDT $COMPONENT_WARNING\n" $COMPONENTS_PER_SERVER
    COMPONENTS_PER_SERVER=1
  fi
  VOLUME_SIZE=$MDT_SIZE
  VOLUME_TYPE=$MDT_VOLUME_TYPE
  THROUGHPUT=$MDT_THROUGHPUT
  IOPS=$MDT_IOPS
  POOL_START_INDEX=$MDT_POOL_START_INDEX
elif [[ "$COMPONENT_TYPE" == "ost" ]]; then
  COMPONENTS_PER_SERVER=$OSTS_PER_OSS
  if [[ "$OST_USE_LOCAL" == "true" && $COMPONENTS_PER_SERVER -gt 1 ]]; then
    printf "Warning: OST $COMPONENT_WARNING\n" $COMPONENTS_PER_SERVER
    COMPONENTS_PER_SERVER=1
  fi
  VOLUME_SIZE=$OST_SIZE
  VOLUME_TYPE=$OST_VOLUME_TYPE
  THROUGHPUT=$OST_THROUGHPUT
  IOPS=$OST_IOPS
  POOL_START_INDEX=$OST_POOL_START_INDEX
else
  echo "Error: Invalid component type '$COMPONENT_TYPE'"
  echo "Component type must be 'mgt', 'mdt', or 'ost'"
  exit 1
fi




# Early validation for local storage configuration
if [[ "$COMPONENT_TYPE" == "mdt" || "$COMPONENT_TYPE" == "ost" ]]; then
  use_local=false
  case ${COMPONENT_TYPE} in
    mdt)
      use_local=$MDT_USE_LOCAL
      ;;
    ost)
      use_local=$OST_USE_LOCAL
      ;;
  esac
  
  if [[ "$use_local" == "true" && $COMPONENTS_PER_SERVER -gt 1 ]]; then
    echo "Error: When using local NVMe storage, only 1 component per server is supported"
    echo "Current setting: COMPONENTS_PER_SERVER=$COMPONENTS_PER_SERVER"
    exit 1
  fi
fi

# Extract server number from hostname (e.g., oss005 -> 5)
server_num=$(echo ${HOSTNAME} | grep -o '[0-9]*$')
server_num=$((10#${server_num}))

echo "===== Creating ${COMPONENT_TYPE^^} components for ${FS_NAME} on ${HOSTNAME} ====="
echo "Server number: ${server_num}"
echo "Components per server: ${COMPONENTS_PER_SERVER}"

# Calculate starting indices
lustre_start_index=$((server_num * COMPONENTS_PER_SERVER - COMPONENTS_PER_SERVER))
pool_start_index=$((server_num * COMPONENTS_PER_SERVER - COMPONENTS_PER_SERVER + POOL_START_INDEX))

if [[ "$COMPONENT_TYPE" == "mgt" ]]; then
  # MGT requires mirrored volumes
  echo "=== Creating mirrored MGT ==="
  
  pool_tag="mgtpool0"
  if sudo zpool list ${pool_tag} >/dev/null 2>&1; then
    echo "Error: ZFS pool ${pool_tag} already exists"
    exit 1
  fi

  dataset_tag="mgt0"
  mount_tag="/lustre/${FS_NAME}/mgt0"
  
  # Create two EBS volumes for mirroring
  name_tag1="${FS_NAME}_${HOSTNAME}_mgt_mirror_1"
  name_tag2="${FS_NAME}_${HOSTNAME}_mgt_mirror_2"
  
  echo "Creating first MGT volume..."
  sudo $EBS_COMM \
    --size $VOLUME_SIZE \
    --volume-type $VOLUME_TYPE \
    --throughput $THROUGHPUT \
    --iops $IOPS \
    --tag "Name:${name_tag1}" \
    --tag "FileSystem:${FS_NAME}" \
    --tag "Component:${COMPONENT_TYPE}" \
    --tag "PoolName:${pool_tag}" \
    --tag "DatasetName:${dataset_tag}" \
    --tag "MountPoint:${mount_tag}"
  
  echo "Creating second MGT volume..."
  sudo $EBS_COMM \
    --size $VOLUME_SIZE \
    --volume-type $VOLUME_TYPE \
    --throughput $THROUGHPUT \
    --iops $IOPS \
    --tag "Name:${name_tag2}" \
    --tag "FileSystem:${FS_NAME}" \
    --tag "Component:${COMPONENT_TYPE}" \
    --tag "PoolName:${pool_tag}" \
    --tag "DatasetName:${dataset_tag}" \
    --tag "MountPoint:${mount_tag}"
  
  # Get device names
  instance_id=$(get_metadata "instance-id")
  az=$(get_metadata "placement/availability-zone")
  region=${az%?}
  
  device1=$(aws ec2 describe-volumes --region "${region}" --filters "Name=tag:Name,Values=${name_tag1}" "Name=attachment.instance-id,Values=${instance_id}" --query "Volumes[0].Tags[?Key=='Device_Name'].Value" --output text)
  device2=$(aws ec2 describe-volumes --region "${region}" --filters "Name=tag:Name,Values=${name_tag2}" "Name=attachment.instance-id,Values=${instance_id}" --query "Volumes[0].Tags[?Key=='Device_Name'].Value" --output text)
  
  # Create mirrored ZFS pool
  echo "Creating mirrored ZFS pool ${pool_tag}..."
  sudo zpool create -f -O canmount=off -o cachefile=none ${pool_tag} mirror ${device1} ${device2}
  
  # Create MGT
  echo "Creating MGT..."
  sudo mkfs.lustre --mgs --backfstype=zfs ${pool_tag}/${dataset_tag}
  
  # Mount MGT
  mount_point="/lustre/${FS_NAME}/${dataset_tag}"
  echo "Creating mount point ${mount_point}..."
  sudo mkdir -p ${mount_point}
  
  echo "Mounting MGT..."
  sudo mount -t lustre ${pool_tag}/${dataset_tag} ${mount_point}
  
  echo "MGT setup complete"
elif [[ "$COMPONENT_TYPE" == "mdt" || "$COMPONENT_TYPE" == "ost" ]]; then
  # Standard component creation for MDT/OST
  for ((i=0; i<COMPONENTS_PER_SERVER; i++)); do
    lustre_index=$((lustre_start_index + i))
    pool_index=$((pool_start_index + i))
    
    echo "=== Creating ${COMPONENT_TYPE^^} ${lustre_index} (pool ${pool_index}) ==="
    
    # Check if ZFS pool already exists
    pool_tag="${COMPONENT_TYPE}pool${pool_index}"
    if sudo zpool list ${pool_tag} >/dev/null 2>&1; then
      if [[ "$FIX_FAILED_CREATE" == "true" ]]; then
        echo "Warning: ZFS pool ${pool_tag} already exists - continuing with --fix-failed-create"
        # Check if Lustre component already mounted
        mount_point="/lustre/${FS_NAME}/${COMPONENT_TYPE}${pool_index}"
        if mount | grep -q "${mount_point}"; then
          echo "${COMPONENT_TYPE^^} ${lustre_index} already mounted at ${mount_point} - skipping"
          continue
        fi
      else
        echo "Error: ZFS pool ${pool_tag} already exists"
        echo "Note: For multiple file systems, update MDT_POOL_START_INDEX or OST_POOL_START_INDEX variables"
        echo "      Or use --fix-failed-create to continue with existing pools"
        exit 1
      fi
    fi
    
    dataset_tag="${COMPONENT_TYPE}${pool_index}"
    mount_tag="/lustre/${FS_NAME}/${COMPONENT_TYPE}${pool_index}"
    
    # Check if using local storage
    use_local=false
    case ${COMPONENT_TYPE} in
      mdt)
        use_local=$MDT_USE_LOCAL
        ;;
      ost)
        use_local=$OST_USE_LOCAL
        ;;
    esac
    
    # Use local NVMe storage if configured
    if [[ "$use_local" == "true" ]]; then
      echo "Using local NVMe storage"
      
      # Get Instance Store device
      nvme_device=$(sudo nvme list 2>/dev/null | grep 'Instance Storage' | awk '{print $1}' | head -1)
      if [[ -z "$nvme_device" ]]; then
        echo "Error: No Instance Store device found on ${HOSTNAME}"
        exit 1
      fi
      
      echo "Using Instance Store device: ${nvme_device}"
      echo "Creating ZFS pool ${pool_tag} with ${nvme_device}"
      sudo zpool create -f -O canmount=off -o cachefile=none ${pool_tag} ${nvme_device}
    else
      # Create EBS volume
      name_tag="${FS_NAME}_${HOSTNAME}_${COMPONENT_TYPE}${lustre_index}"
      
      echo "Creating EBS volume with tags..."
      sudo $EBS_COMM \
        --size $VOLUME_SIZE \
        --volume-type $VOLUME_TYPE \
        --throughput $THROUGHPUT \
        --iops $IOPS \
        --tag "Name:${name_tag}" \
        --tag "FileSystem:${FS_NAME}" \
        --tag "Component:${COMPONENT_TYPE}" \
        --tag "LustreIndex:${lustre_index}" \
        --tag "PoolIndex:${pool_index}" \
        --tag "PoolName:${pool_tag}" \
        --tag "DatasetName:${dataset_tag}" \
        --tag "MountPoint:${mount_tag}"
      
      # Get the device name from the volume tags
      echo "Finding EBS device..."
      instance_id=$(get_metadata "instance-id")
      az=$(get_metadata "placement/availability-zone")
      region=${az%?}  # Remove the last character from AZ to get region
      device=$(aws ec2 describe-volumes \
        --region "${region}" \
        --filters "Name=tag:Name,Values=${name_tag}" \
                  "Name=attachment.instance-id,Values=${instance_id}" \
        --query "Volumes[0].Tags[?Key=='Device_Name'].Value" --output text)
      
      if [[ -z "$device" ]]; then
        echo "Error: Could not find device for volume ${name_tag}"
        exit 1
      fi
      
      echo "Using device: $device"
      
      # Create ZFS pool
      echo "Creating ZFS pool ${pool_tag}..."
      sudo zpool create -f -O canmount=off -o cachefile=none ${pool_tag} ${device}
    fi
    
    # Create Lustre component
    echo "Creating Lustre ${COMPONENT_TYPE^^} ${lustre_index}..."
    sudo mkfs.lustre \
      --${COMPONENT_TYPE} \
      --backfstype=zfs \
      --fsname=${FS_NAME} \
      --index=${lustre_index} \
      --mgsnode=${MGS_NODE} \
      ${pool_tag}/${dataset_tag}
    
    # Create mount point and mount
    mount_point="/lustre/${FS_NAME}/${dataset_tag}"
    echo "Creating mount point ${mount_point}..."
    sudo mkdir -p ${mount_point}
    
    echo "Mounting ${COMPONENT_TYPE^^} ${lustre_index}..."
    sudo mount -t lustre ${pool_tag}/${dataset_tag} ${mount_point}
    
    echo "${COMPONENT_TYPE^^} ${lustre_index} setup complete"
  done
fi

echo "===== All ${COMPONENT_TYPE^^} components created successfully on ${HOSTNAME} ====="