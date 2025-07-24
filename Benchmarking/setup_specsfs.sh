#!/usr/bin/bash
#
# Automated SPEC SFS 2014 SP2 Benchmark Script
#

# Exit on error
set -e

# PDSH command with SSH options to suppress warnings
export PDSH_SSH_ARGS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=~/known_hosts -o LogLevel=ERROR"

# Parse command line arguments
FS_MOUNT_POINT=""
PDSH_HOST_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --fs-mount-point)
            FS_MOUNT_POINT="$2"
            shift 2
            ;;
        --pdsh-host-file)
            PDSH_HOST_FILE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 --fs-mount-point <mount_point> --pdsh-host-file <host_file>"
            exit 1
            ;;
    esac
done

# Check required arguments
if [ -z "$FS_MOUNT_POINT" ]; then
    echo "Error: --fs-mount-point is required"
    echo "Usage: $0 --fs-mount-point <mount_point> --pdsh-host-file <host_file>"
    exit 1
fi

if [ -z "$PDSH_HOST_FILE" ]; then
    echo "Error: --pdsh-host-file is required"
    echo "Usage: $0 --fs-mount-point <mount_point> --pdsh-host-file <host_file>"
    exit 1
fi

# Check for ISO file
SPEC_INSTALL_FILE="SPECsfs2014_SP2.iso"
[ -f  ${SPEC_INSTALL_FILE} ] || (echo "Error: SPEC SFS Install ${SPEC_INSTALL_FILE} file not available" && exit 1)

# Configuration variables
INSTALL_PATH="$HOME/SPEC/SPECsfs/execute"
TEST_DIR="$FS_MOUNT_POINT/specsfs_test.d"

## License key is a requirement and specsfs will fail if not provided
SECRET_NAME="licenses/fs-license" ## Needs to be changed
LICENSE_KEY="${SPEC_LICENSE_KEY:-$(aws secretsmanager get-secret-value \
    --secret-id $SECRET_NAME \ 
    --query SecretString \
    --output text \
    | cut -d'"' -f4 )}"

SPEC_RUN_DIR="$(dirname "$0")/SPEC_SFS_Run"
FS_MGR_NODE="mgs01"

# Check for cluster batch file
if [ ! -f $PDSH_HOST_FILE ]; then
    echo "Error: $PDSH_HOST_FILE file not found"
    echo "This file is required to identify batch nodes for the benchmark"
    exit 1
fi
echo "Found $PDSH_HOST_FILE file"

# Check file system mount on all batch nodes
echo "Checking file system mount on batch nodes..."
mount_chk=$(pdsh -w ^$PDSH_HOST_FILE "mountpoint -q $FS_MOUNT_POINT || echo \$(hostname): not mounted")

if echo "$mount_chk" | grep -q "not mounted"; then
    echo "Error: File system is not mounted on some or all batch nodes at $FS_MOUNT_POINT"
    echo "Please mount the file system on all batch nodes before running this script"
    echo "Example mount command: sudo mount -t <fs_type> <server>:<export> $FS_MOUNT_POINT"
    echo ""
    echo "Lustre example:"
    echo "   pdsh -w ^$PDSH_HOST_FILE sudo mkdir $FS_MOUNT_POINT"
    echo "   pdsh -w ^$PDSH_HOST_FILE sudo mount -t lustre mgs01:$FS_MOUNT_POINT $FS_MOUNT_POINT"
    exit 1
else
    echo "File system is mounted on all batch nodes at $FS_MOUNT_POINT"
fi

# Create SPEC SFS run directory
if [ ! -d "$SPEC_RUN_DIR" ]; then
    echo "Creating SPEC SFS run directory: $SPEC_RUN_DIR"
    if ! mkdir -p "$SPEC_RUN_DIR"; then
        echo "Error: Failed to create SPEC SFS run directory: $SPEC_RUN_DIR"
        exit 1
    fi
else
    echo "SPEC SFS run directory already exists: $SPEC_RUN_DIR"
fi

echo "===== Creating Python virtual environment ====="
echo "Python version detection and virtual environment setup"

# Create virtual environment directory
if [ ! -d ~/Envs ]; then
    echo "Creating ~/Envs directory for virtual environments"
    if ! mkdir ~/Envs; then
        echo "Error: Failed to create ~/Envs directory"
        exit 1
    fi
else
    echo "Virtual environment directory ~/Envs already exists"
fi

# Check for latest Python version and create venv
if command -v python3.11 &> /dev/null; then
    PYTHON_CMD="python3.11"
elif command -v python3.9 &> /dev/null; then
    PYTHON_CMD="python3.9"
elif command -v python3.8 &> /dev/null; then
    PYTHON_CMD="python3.8"
else
    echo "No suitable Python version found (need 3.8+)"
    exit 1
fi

echo "Using Python: $PYTHON_CMD"
echo "Creating virtual environment at ~/Envs/specsfs"
if ! $PYTHON_CMD -m venv ~/Envs/specsfs; then
    echo "Error: Failed to create Python virtual environment"
    exit 1
fi

echo "Activating virtual environment"
if ! source ~/Envs/specsfs/bin/activate; then
    echo "Error: Failed to activate Python virtual environment"
    exit 1
fi
echo "Active Python: $(which python)"
echo "Python version: $(python --version)"

echo ""
echo "===== Installing SPEC SFS from ISO ====="
echo "Mounting ISO file: ${SPEC_INSTALL_FILE}"

# Create mount point if needed
if [ ! -d /mnt/iso ]; then
    echo "Creating mount point /mnt/iso"
    sudo mkdir /mnt/iso
fi

# Mount ISO if not already mounted
if ! mountpoint -q /mnt/iso; then
    echo "Mounting ISO to /mnt/iso"
    sudo mount -o loop ${SPEC_INSTALL_FILE} /mnt/iso
else
    echo "ISO already mounted at /mnt/iso"
fi

echo "Installing SPEC SFS to: ${INSTALL_PATH}"
cd /mnt/iso

# Temporarily disabling exit on error, because the SPEC SFS install 
#  returns 1, even though it successfully installs
set +e
SPEC_INST_MSG=$(python SfsManager --install-dir=${INSTALL_PATH} 2>&1)
set -e

if echo "$SPEC_INST_MSG" | grep -q "SPEC SFS2014_SP2 successfully installed"; then
    echo "SPEC SFS installation complete"
else
    echo "SPEC SFS installation failed:"
    echo "$SPEC_INST_MSG"
    cd $HOME
    exit 1
fi
cd $HOME

# Clean up ISO mount
echo "Cleaning up ISO mount"
if mountpoint -q /mnt/iso; then
    sudo umount /mnt/iso
    echo "ISO unmounted"
fi

if [ -d /mnt/iso ]; then
    sudo rmdir /mnt/iso
    echo "Mount directory removed"
fi

# Install Python dependencies
echo ""
echo "===== Installing Python dependencies ====="
echo "Installing matplotlib for report generation"
pip install matplotlib
echo "Python dependencies installed"

# Setup test directories (SPEC SFS runs from head node)
echo ""
echo "===== Setting up test directories ====="
ssh -o StrictHostKeyChecking=no $FS_MGR_NODE "sudo mkdir -p $TEST_DIR && sudo chown ec2-user:ec2-user $TEST_DIR"
echo "Test $TEST_DIR directory created on $FS_MGR_NODE"

echo "Verifying test directory exists on all batch nodes..."
pdsh -w ^$PDSH_HOST_FILE "ls -ld $TEST_DIR" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "Test directory verified on all batch nodes"
else
    echo "Warning: Test directory may not be accessible on some batch nodes"
    echo "This could indicate file system mount issues"
fi
echo "Test directory setup complete"

# Create SPEC SFS configuration file
echo ""
echo "===== Creating SPEC SFS configuration file ====="
echo "Generating sfs_eda_rc configuration file"
cat > "$SPEC_RUN_DIR/sfs_eda_rc" << 'EOF'
##############################################################################
#
#	sfs_rc
#
# Specify netmist parameters for generic runs in this file.
#
# The following parameters are configurable within the SFS run and
# reporting rules.
#
# Official BENCHMARK values are
#	-SWBUILD
#	-VDA
#	-VDI
#	-DATABASE
#	-EDA
#
##############################################################################

BENCHMARK=EDA
LOAD=10
INCR_LOAD=10
NUM_RUNS=10
CLIENT_MOUNTPOINTS=spec_sfs.clients
EXEC_PATH=/home/ec2-user/SPEC/SPECsfs/execute/binaries/linux/x86_64/netmist
#USER=centos
USER=ec2-user
WARMUP_TIME=300
IPV6_ENABLE=0
PRIME_MON_SCRIPT=
PRIME_MON_ARGS=
NETMIST_LOGS=
INIT_RATE=0

##############################################################################
#
# Specifying a password is only required for Windows clients
#
##############################################################################
PASSWORD=
##############################################################################
#
#  DO NOT EDIT BELOW THIS LINE FOR AN OFFICIAL BENCHMARK SUBMISSION
#
#  Constraints and overrides on the values below this line can be found in the
#  benchmark XML file (default is benchmarks.xml).  To bypass all overrides
#  use the --ignore-overrides flag in SfsManager.  Using the flag will make
#  the results invalid for formal submission.
#
##############################################################################
RUNTIME=300
WORKLOAD_FILE=
OPRATE_MULTIPLIER=
CLIENT_MEM=1g
AGGR_CAP=1g
FILE_SIZE=
DIR_COUNT=10
FILES_PER_DIR=100
UNLINK_FILES=0
LATENCY_GRAPH=1
HEARTBEAT_NOTIFICATIONS=1
DISABLE_FSYNCS=0
USE_RSHRCP=0
BYTE_OFFSET=0
MAX_FD=
PIT_SERVER=
PIT_PORT=
LOCAL_ONLY=0
FILE_ACCESS_LIST=0
SHARING_MODE=0
SOCK_DEBUG=0
TRACEDEBUG=0
NO_OP_VALIDATE=0
NO_SHARED_BUCKETS=0
UNLINK2_NO_RECREATE=0
EOF

echo "Configuration file created with EDA benchmark settings"

# Generate client list based on physical cores
echo ""
echo "===== Generating client list based on physical cores ====="
echo "Querying batch nodes for physical core counts"
pdsh_core_count=$(pdsh -w ^$PDSH_HOST_FILE 'echo "$(hostname) $(lscpu | awk "/^Socket\(s\):/ {sockets=\$2} /^Core\(s\) per socket:/ {cores=\$4} END {print sockets*cores}")"' 2>/dev/null | sort)

echo "Processing core counts and generating client entries"
while read line; do
  hostname=${line%: *}
  cores=${line##* }
  for n in $(seq 1 ${cores}); do
    echo $hostname $TEST_DIR
  done
done <<< "$pdsh_core_count" > "$SPEC_RUN_DIR/spec_sfs.clients"

echo "Generated client list with $(wc -l < "$SPEC_RUN_DIR/spec_sfs.clients") total entries"
echo "Client list saved as: $SPEC_RUN_DIR/spec_sfs.clients"

# Create license file
echo ""
echo "===== Creating license file ====="
echo "Creating netmist license file with key: $LICENSE_KEY"
echo "LICENSE KEY $LICENSE_KEY" > "$SPEC_RUN_DIR/netmist_license_key"
echo "License file created at: $SPEC_RUN_DIR/netmist_license_key"
echo ""

echo ""
echo "========================================"
echo "=== SPEC SFS Setup Complete ===="
echo "========================================"
echo ""
echo "Setup Summary:"
echo "  SPEC SFS Installation: $INSTALL_PATH"
echo "  Run Directory:         $SPEC_RUN_DIR"
echo "  Test Directory:        $TEST_DIR"
echo "  Client Entries:        $(wc -l < "$SPEC_RUN_DIR/spec_sfs.clients")"
echo "  License Key:           $LICENSE_KEY"
echo ""
echo "Configuration Files (in $SPEC_RUN_DIR):"
echo "  - sfs_eda_rc (benchmark configuration)"
echo "  - spec_sfs.clients (client node list)"
echo "  - netmist_license_key (license file)"
echo ""
echo "========================================"
echo "=== Next Steps: Run the Benchmark ===="
echo "========================================"
echo ""
echo "1. Navigate to run directory:"
echo "   cd $SPEC_RUN_DIR"
echo ""
echo "2. Activate the Python virtual environment:"
echo "   source ~/Envs/specsfs/bin/activate"
echo ""
echo "3. Start screen session (recommended for long runs):"
echo "   screen"
echo ""
echo "4. Execute the benchmark:"
echo "   python $INSTALL_PATH/SfsManager -b $INSTALL_PATH/benchmarks.xml -r sfs_eda_rc -s specsfs_test"
echo ""
echo "5. Monitor progress:"
echo "   - Results will be saved in the 'results' directory"
echo "   - Use 'tail -f results/*.log' to monitor progress"
echo "   - Detach from screen with Ctrl+A, D"
echo "   - Reattach with 'screen -r'"
echo ""
echo "Benchmark will run EDA workload with 10 load increments starting at 10 ops/sec"
echo "Expected runtime: ~50 minutes (10 runs × 5 minutes each)"