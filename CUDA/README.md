# CUDA Installation Guide

This guide provides step-by-step instructions for installing NVIDIA CUDA Toolkit on Ubuntu systems.

## Prerequisites

Before installing CUDA, ensure your system meets the following requirements:

- **Operating System**: Ubuntu (tested on 22.04/24.04)
- **System Updates**: Updated system
- **Development Tools**: GCC/G++ compiler matching kernel version
- **NVIDIA GPU**: Instance with NVIDIA graphics card

### System Preparation

1. **Update your system**:
   ```bash
   sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y
   ```

2. **Verify compiler installation**:
   ```bash
   cat /proc/version
   gcc --version
   g++ --version
   ```

## Installation Steps

### 1. Download CUDA Toolkit

1. Visit the [NVIDIA CUDA Downloads](https://developer.nvidia.com/cuda-downloads) page
2. Select your system architecture and OS version
3. Download the installer:
   ```bash
   wget https://developer.download.nvidia.com/compute/cuda/[VERSION]/[INSTALLER_NAME]
   ```

### 2. Run the Installer

Execute the interactive installer:
```bash
sudo sh cuda_[VERSION]_linux.run
```

Successful installation will display something similar to this:
```
===========
= Summary =
===========

Driver:   Installed
Toolkit:  Installed in /usr/local/cuda-12.6/

Please make sure that
 -   PATH includes /usr/local/cuda-12.6/bin
 -   LD_LIBRARY_PATH includes /usr/local/cuda-12.6/lib64, or, add /usr/local/cuda-12.6/lib64 to /etc/ld.so.conf and run ldconfig as root

To uninstall the CUDA Toolkit, run cuda-uninstaller in /usr/local/cuda-12.6/bin
To uninstall the NVIDIA Driver, run nvidia-uninstall
Logfile is /var/log/cuda-installer.log
```

Add CUDA to your environment by editing `~/.bashrc`:
```bash
export PATH="/usr/local/cuda-12.6/bin:$PATH"
export LD_LIBRARY_PATH="/usr/local/cuda-12.6/lib64:$LD_LIBRARY_PATH"
```

Verify your CUDA installation:
```bash
nvcc --version
nvidia-smi
```

## CUDA Samples (Optional)

To test your installation with sample programs:

1. **Download CUDA Samples**:
   - Repository: [NVIDIA CUDA Samples](https://github.com/NVIDIA/cuda-samples)
   - Ensure sample version matches your CUDA toolkit version

2. **Version Compatibility**:
   - Compare `nvcc --version` output with sample release date
   - Use samples that match your CUDA toolkit version




