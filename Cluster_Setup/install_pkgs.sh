#!/bin/bash
# install_pkgs.sh - Simple package installation
#
# Usage: install_pkgs.sh <package_list>

set -e

# Use dnf without subscription manager (for RHEL systems)
DNF="dnf --disableplugin=subscription-manager -q"

# Comprehensive RPM/DNF lock and hang handling
chk_clean_rpm_processes() {
    local wait_time=60  # Wait 60 seconds for legitimate operations
    
    # 1. Check if lock exists and if processes are using RPM database
    if [ -f /var/lib/rpm/.rpm.lock ]; then
        # Check for legitimate RPM processes
        if sudo fuser -v /var/lib/rpm 2>/dev/null | grep -q rpm; then
            sleep $wait_time
            
            # Check again after wait
            if sudo fuser -v /var/lib/rpm 2>/dev/null | grep -q rpm; then
                # Kill only if processes appear hung (no recent activity)
                sudo fuser -k /var/lib/rpm/.rpm.lock 2>/dev/null || true
                sleep 2
            fi
        fi
        
        # Remove lock if no active processes or after cleanup
        sudo rm -f /var/lib/rpm/.rpm.lock 2>/dev/null || true
    fi
    
    # 2. Clean up any remaining hung processes
    sudo pkill -f "dnf.*install|yum.*install" 2>/dev/null || true
    
    # 3. Remove DNF locks
    sudo rm -f /var/lib/dnf/locks/* 2>/dev/null || true
    
    # 4. Check for database corruption and rebuild if needed
    if ! sudo $DNF list installed >/dev/null 2>&1; then
        sudo cp -r /var/lib/rpm /var/lib/rpm.backup.$(date +%s) 2>/dev/null || true
        sudo rpm --rebuilddb
        sleep 3
    fi
}

# Check which packages are missing
check_missing_packages() {
    local packages="$*"
    local installed_output
    local missing_packages=""
    
    # Clean up any locks before checking packages
    chk_clean_rpm_processes
    
    # Get list of installed packages
    installed_output=$(sudo $DNF list installed $packages 2>/dev/null || true)
    
    # Check each package
    for pkg in $packages; do
        if ! echo "$installed_output" | grep -q "^$pkg\."; then
            missing_packages="$missing_packages $pkg"
        fi
    done
    
    echo "$missing_packages"
}

# Install missing packages
install_packages() {
    local missing_packages="$*"
    local max_attempts=3
    
    if [ -z "$missing_packages" ]; then
        return 0
    fi
    
    for attempt in $(seq 1 $max_attempts); do
        chk_clean_rpm_processes
        
        # Try installation with timeout
        if timeout 300 sudo $DNF -y install $missing_packages >/dev/null 2>&1; then
            return 0
        fi
        
        sleep 10
    done
    
    return 1
}

# Main script logic
if [ $# -eq 0 ]; then
    echo "Usage: $0 <package_list>"
    exit 1
fi

# Check which packages are missing
missing_packages=$(check_missing_packages "$@")

if [ -z "$missing_packages" ]; then
    echo "ALL_INSTALLED"
    exit 0
fi

# Try to install missing packages
if install_packages "$missing_packages"; then
    echo "SUCCESS"
else
    echo "ERROR"
    exit 1
fi