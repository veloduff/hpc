#!/bin/bash

# Get file system size argument
FILE_SYSTEM_SIZE="$1"

# Validate file system size argument
if [[ -z "$FILE_SYSTEM_SIZE" ]]; then
    echo "ERROR: File system size argument is required"
    echo "Usage: $0 <size>"
    echo "Available sizes: small, medium, large, xlarge, local"
    exit 1
fi

case "$FILE_SYSTEM_SIZE" in
    "small"|"medium"|"large"|"xlarge"|"local")
        # Valid size
        ;;
    *)
        echo "ERROR: Invalid file system size '$FILE_SYSTEM_SIZE'"
        echo "Available sizes: small, medium, large, xlarge, local"
        exit 1
        ;;
esac

# Redirect output and errors to log file
LOG_FILE="$(dirname "$0")/pcluster-lustre-post-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "===== Running Post-Install Scripts ====="
echo "Log file: $LOG_FILE"
echo "File system size: $FILE_SYSTEM_SIZE"
echo "Started at: $(date)"
echo

# Run main cluster setup
echo "Running cluster setup script..."
$HOME/cluster_setup.sh
if [ $? -ne 0 ]; then
    echo "ERROR: cluster_setup.sh failed with exit code $?"
    exit 1
fi
echo "cluster_setup.sh completed successfully"
echo

# Run Lustre hosts files fix
echo "Running Lustre hosts files fix..."
$HOME/fix_lustre_hosts_files.sh
if [ $? -ne 0 ]; then
    echo "ERROR: fix_lustre_hosts_files.sh failed with exit code $?"
    exit 1
fi
echo "fix_lustre_hosts_files.sh completed successfully"
echo

# Run Lustre setup
echo "Running Lustre setup..."
$HOME/setup_lustre.sh --fs-size "$FILE_SYSTEM_SIZE"
if [ $? -ne 0 ]; then
    echo "ERROR: setup_lustre.sh failed with exit code $?"
    exit 1
fi
echo "setup_lustre.sh completed successfully"

echo
echo "===== All Post-Install Scripts Complete ====="
echo "Completed at: $(date)"