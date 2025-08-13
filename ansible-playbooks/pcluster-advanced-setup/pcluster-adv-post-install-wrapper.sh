#!/bin/bash

# Redirect output and errors to log file
LOG_FILE="$(dirname "$0")/pcluster-adv-post-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "===== Running Advanced Cluster Post-Install Scripts ====="
echo "Log file: $LOG_FILE"
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

echo "===== Advanced Cluster Post-Install Complete ====="
echo "Completed at: $(date)"