#!/bin/bash
#==============================================================================
# setup_lustre.sh - Automated Lustre File System Setup on AWS
#==============================================================================
#
# DESCRIPTION:
#   This script orchestrates the creation of a complete Lustre parallel file system
#   on AWS EC2 instances using ZFS backend storage. It uses a modular approach with
#   create_lustre_components.sh to handle individual component creation:
#   - MGT (Management Target) on MGS (Management Server) with mirrored volumes
#   - MDT (Metadata Target) on MDS (Metadata Server) nodes  
#   - OST (Object Storage Target) on OSS (Object Storage Server) nodes
#
# ARCHITECTURE:
#   - Modular design using create_lustre_components.sh for component creation
#   - Supports both local NVMe storage and EBS volumes
#   - Parallel execution using pdsh for efficiency
#   - Component-specific configurations defined in create_lustre_components.sh
#   - Automatic hostname-based component type detection
#
# PREREQUISITES:
#   1. EC2 instances with appropriate IAM permissions for EBS operations
#   2. ZFS and Lustre kernel modules installed on all servers
#   3. SSH access between nodes with key-based authentication
#   4. pdsh installed for parallel command execution
#   5. Required hostname files:
#      - cluster.mgs: MGS server hostname (single node)
#      - cluster.mds: MDS server hostnames
#      - cluster.oss: OSS server hostnames
#   6. Required scripts:
#      - ebs_create_attach.sh: EBS volume creation and attachment
#      - create_lustre_components.sh: Individual Lustre component creation
#
# USAGE:
#   1. Review and modify configuration parameters below
#   2. Ensure all prerequisite files and scripts are in place
#   3. Execute: ./setup_lustre.sh
#
# MULTIPLE FILE SYSTEM SUPPORT:
#   - Each file system requires unique MDT_POOL_START_INDEX and OST_POOL_START_INDEX
#   - Single MGS manages all file systems using one MGT
#   - Lustre component indices always start at 0 for each file system
#   - Component configurations (sizes, IOPS, etc.) defined in create_lustre_components.sh
#
#==============================================================================

set -e

#==============================================================================
# FILE SYSTEM AND STORAGE CONFIGURATION
#
# STORAGE OPTIONS:
#   Local NVMe (Instance Store): High performance, ephemeral, one per server
#   EBS Volumes: Persistent, configurable IOPS/throughput, multiple per server
#
# MULTIPLE FILE SYSTEM SUPPORT:
#   - Each file system needs unique ZFS pool indices (MDT_POOL_START_INDEX, OST_POOL_START_INDEX)
#   - Lustre component indices always start at 0 for each file system (MDT0, OST0)
#   - Single MGS manages all file systems using one MGT
#
# EXAMPLES:
#   First file system (scratch):  MDT_POOL_START_INDEX=0 (from 0 to 3), OST_POOL_START_INDEX=0 (from 0 to 39)
#   Second file system (projects): MDT_POOL_START_INDEX=4, OST_POOL_START_INDEX=40
#==============================================================================

DEBUG=false                        # Set to true for verbose output
EXTEND_EXISTING_FS=false           # Set to true to extend existing file system
FIX_FAILED_CREATE=false            # Set to true to fix failed file system creation
USE_LOCAL_DISKS=false              # Set to true to use local NVMe storage
FS_SIZE_CONFIG="large"             # Default file system size configuration

# Set the default file system name 
FS_NAME="projects"                 # "projects" "eda-tools" etc. 
#FS_NAME="scratch"                  # "scratch" should be used is using local disks - Instance Store

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --extend-existing-fs)
      EXTEND_EXISTING_FS=true
      shift
      ;;
    --fix-failed-create)
      FIX_FAILED_CREATE=true
      shift
      ;;
    --fs-name)
      FS_NAME="$2"
      shift 2
      ;;
    --use-local-disks)
      USE_LOCAL_DISKS=true
      shift
      ;;
    --fs-size)
      FS_SIZE_CONFIG="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--extend-existing-fs] [--fix-failed-create] [--fs-name <name>] [--use-local-disks] [--fs-size <size>]"
      exit 1
      ;;
  esac
done


# Hostname files for mgs/mds/oss servers 
MGS_SERVER="$HOME/cluster.mgs"     # File containing MGS server
MDS_SERVERS="$HOME/cluster.mds"    # File containing MDS servers - could be the MGS
OSS_SERVERS="$HOME/cluster.oss"    # File containing OSS servers

MGS_NODE="mgs01"                   # MGS hostname (short name)
MOUNT_BASE="/lustre/${FS_NAME}"    # Base mount point for Lustre server components
CLIENT_MOUNT_POINT="/${FS_NAME}"   # Client mount point for the file system

# Starting indices for multiple file system support
MDT_START_INDEX=0                  # Do not change - Starting index for MDTs (always 0 for each file system)
OST_START_INDEX=0                  # Do not change - Starting index for OSTs (always 0 for each file system)


# Path to the ebs_create_attach.sh script 
EBS_COMM="$HOME/ebs_create_attach.sh"
if [[ ! -f $EBS_COMM ]]; then
  echo "EBS create and attach file $EBS_COMM not found"
  exit 1
fi

# SSH command with options
SSH_COMM="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=~/known_hosts"

# PDSH command with SSH options to suppress warnings
export PDSH_SSH_ARGS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=~/known_hosts -o LogLevel=ERROR"

# Validate file system name length
if [[ ${#FS_NAME} -gt 8 ]]; then
  echo "Error: Lustre file system name '${FS_NAME}' is ${#FS_NAME} characters long"
  echo "Maximum allowed length is 8 characters"
  exit 1
fi

# Path to the create_lustre_components.sh script
CREATE_COMPONENT_SCRIPT="$HOME/create_lustre_components.sh"
if [[ ! -f $CREATE_COMPONENT_SCRIPT ]]; then
  echo "Error: create_lustre_components.sh script not found at $CREATE_COMPONENT_SCRIPT"
  exit 1
fi

# Check if server list files exist
for file in "$MGS_SERVER" "$MDS_SERVERS" "$OSS_SERVERS"; do
  if [ ! -f "$file" ]; then
    echo "Error: Server list file $file not found"
    exit 1
  fi
done

# Check kernel modules on all servers in parallel
echo "===== Checking kernel modules on all servers ====="

# Check ZFS modules
echo "Checking ZFS modules..."
zfs_missing=$(pdsh -w ^"$MGS_SERVER",^"$MDS_SERVERS",^"$OSS_SERVERS" "lsmod | grep -q zfs || echo \"\$(hostname): missing\"" | grep missing || true)
if [[ -n "$zfs_missing" ]]; then
  echo "Loading ZFS modules..."
  pdsh -w ^"$MGS_SERVER",^"$MDS_SERVERS",^"$OSS_SERVERS" "lsmod | grep -q zfs || sudo modprobe zfs"
fi

# Check Lustre modules
echo "Checking Lustre modules..."
lustre_missing=$(pdsh -w ^"$MGS_SERVER",^"$MDS_SERVERS",^"$OSS_SERVERS" "lsmod | grep -q lustre || echo \"\$(hostname): missing\"" | grep missing || true)
if [[ -n "$lustre_missing" ]]; then
  echo "Loading Lustre modules..."
  pdsh -w ^"$MGS_SERVER",^"$MDS_SERVERS",^"$OSS_SERVERS" "lsmod | grep -q lustre || sudo modprobe lustre"
fi

echo "Kernel module check complete"

# Check for existing file system on MGS
echo "Checking for existing Lustre file system '${FS_NAME}'..."
mgs_server=$(head -1 $MGS_SERVER)
if ${SSH_COMM} ${mgs_server} "sudo lctl dl -t 2>/dev/null | grep -q '${FS_NAME}'"; then
  if [[ "$EXTEND_EXISTING_FS" != "true" && "$FIX_FAILED_CREATE" != "true" ]]; then
    echo "Error: Lustre file system '${FS_NAME}' already exists on MGS"
    echo "Use --extend-existing-fs flag to add components to existing file system"
    echo "Or use --fix-failed-create flag to fix failed file system creation"
    exit 1
  elif [[ "$EXTEND_EXISTING_FS" == "true" ]]; then
    echo "Extending existing Lustre file system '${FS_NAME}'"
  elif [[ "$FIX_FAILED_CREATE" == "true" ]]; then
    echo "Fixing failed creation of Lustre file system '${FS_NAME}'"
  fi
fi

# Create base mount directory on all servers
echo "Creating base mount directories..."
pdsh -w ^"$MGS_SERVER",^"$MDS_SERVERS",^"$OSS_SERVERS" "sudo mkdir -p ${MOUNT_BASE}"

# Get existing pool indices for multiple file system support
echo "Checking for existing ZFS pools..."
MDT_NEXT_POOL_IDX=0
OST_NEXT_POOL_IDX=0

# Get highest MDT pool index
MDT_POOLS=$(pdsh -w ^"$MDS_SERVERS" "zpool list 2>/dev/null | grep mdtpool || true" | grep -o 'mdtpool[0-9]*' | sort -V | tail -1 || true)
if [[ -n "$MDT_POOLS" ]]; then
  MDT_LAST_POOL_IDX=$(echo "$MDT_POOLS" | grep -o '[0-9]*$')
  MDT_NEXT_POOL_IDX=$((MDT_LAST_POOL_IDX + 1))
  echo "Found existing MDT pools, next index: $MDT_NEXT_POOL_IDX"
fi

# Get highest OST pool index
OST_POOLS=$(pdsh -w ^"$OSS_SERVERS" "zpool list 2>/dev/null | grep ostpool || true" | grep -o 'ostpool[0-9]*' | sort -V | tail -1 || true)
if [[ -n "$OST_POOLS" ]]; then
  OST_LAST_POOL_IDX=$(echo "$OST_POOLS" | grep -o '[0-9]*$')
  OST_NEXT_POOL_IDX=$((OST_LAST_POOL_IDX + 1))
  echo "Found existing OST pools, next index: $OST_NEXT_POOL_IDX"
fi


# Step 1: Create MGT on the MGS server with mirroring (only create once for all file systems)
mgs_server=$(head -1 $MGS_SERVER)
if ! ${SSH_COMM} ${mgs_server} "mount | grep -q mgtpool0"; then
  echo "===== Creating MGT ====="
  ${SSH_COMM} ${mgs_server} "$CREATE_COMPONENT_SCRIPT --fsname $FS_NAME --fs-type $FS_SIZE_CONFIG"
else
  echo "MGT already exists, skipping creation"
fi

# Step 2: Create MDT components using create_lustre_components.sh
echo "===== Creating MDT components ====="
MDT_ARGS="--fsname $FS_NAME --mgs-node $MGS_NODE --mdt-pool-idx $MDT_NEXT_POOL_IDX --fs-type $FS_SIZE_CONFIG"
if [[ "$EXTEND_EXISTING_FS" == "true" ]]; then
  MDT_ARGS="$MDT_ARGS --extend-existing-fs"
fi
if [[ "$FIX_FAILED_CREATE" == "true" ]]; then
  MDT_ARGS="$MDT_ARGS --fix-failed-create"
fi
if [[ "$USE_LOCAL_DISKS" == "true" ]]; then
  MDT_ARGS="$MDT_ARGS --use-local-disks"
fi
pdsh -S -w ^"$MDS_SERVERS" "$CREATE_COMPONENT_SCRIPT $MDT_ARGS" | dshbak
MDT_EXIT_CODE=${PIPESTATUS[0]}

if [[ $MDT_EXIT_CODE -gt 0 ]]; then
  echo "MDT create failed with exit code $MDT_EXIT_CODE"
  exit $MDT_EXIT_CODE
fi

# Step 3: Create OST components using create_lustre_components.sh
echo "===== Creating OST components ====="
OST_ARGS="--fsname $FS_NAME --mgs-node $MGS_NODE --ost-pool-idx $OST_NEXT_POOL_IDX --fs-type $FS_SIZE_CONFIG"
if [[ "$EXTEND_EXISTING_FS" == "true" ]]; then
  OST_ARGS="$OST_ARGS --extend-existing-fs"
fi
if [[ "$FIX_FAILED_CREATE" == "true" ]]; then
  OST_ARGS="$OST_ARGS --fix-failed-create"
fi
if [[ "$USE_LOCAL_DISKS" == "true" ]]; then
  OST_ARGS="$OST_ARGS --use-local-disks"
fi
pdsh -S -w ^"$OSS_SERVERS" "$CREATE_COMPONENT_SCRIPT $OST_ARGS" | dshbak
OST_EXIT_CODE=${PIPESTATUS[0]}

if [[ $OST_EXIT_CODE -gt 0 ]]; then
  echo "OST create failed with exit code $OST_EXIT_CODE"
  exit $OST_EXIT_CODE
fi

echo "===== Lustre file system setup complete ====="

echo "===== Mounting Lustre file system on servers ====="
pdsh -w ^"$MGS_SERVER",^"$MDS_SERVERS",^"$OSS_SERVERS" "[ -d ${CLIENT_MOUNT_POINT} ] || sudo mkdir -p ${CLIENT_MOUNT_POINT}"
pdsh -w ^"$MGS_SERVER",^"$MDS_SERVERS",^"$OSS_SERVERS" "sudo mount -t lustre ${MGS_NODE}:/${FS_NAME} ${CLIENT_MOUNT_POINT}"

# Set default striping to use all OSTs
# echo "===== Set default striping to use all OSTs ====="
# ${SSH_COMM} ${mgs_server} "sudo lfs setstripe -c -1 ${CLIENT_MOUNT_POINT}"

# Check the stripe configuration
echo "===== Checking default stripe configuration ====="
${SSH_COMM} ${mgs_server} "sudo lfs getstripe -d ${CLIENT_MOUNT_POINT}"

# Check file system usage
echo "===== Checking file system usage ====="
wait_time=10
echo "Waiting $wait_time secs for file system to be fully available..."
sleep $wait_time 
${SSH_COMM} ${mgs_server} "sudo lfs df -h"

echo "===== Lustre file system is ready to use ====="
echo "To mount on clients:"
echo "pdsh -w ^cluster.batch sudo mkdir -p ${CLIENT_MOUNT_POINT}"
echo "pdsh -w ^cluster.batch sudo mount -t lustre ${MGS_NODE}:/${FS_NAME} ${CLIENT_MOUNT_POINT}"


