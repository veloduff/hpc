# Ubuntu Desktop Customization for NICE DCV

Instructions for customizing Ubuntu Desktop environments. 

> **Recommendation**: Complete this process manually, step-by-step and do not use automation. Too many things go wrong durning this process. 

### 1. Update System Packages

```bash
sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y
```

### 2. Fix Firefox

Reinstall Firefox with snap - in installs broken by default
```bash
sudo snap remove firefox
sudo snap install firefox
```

### 3. Install and Configure GCC and G++ to match the version that the kernel was built with

Check with:
```bash
cat /proc/version
```

This example shows version 12 for GCC and G++ :
```bash
# Install GCC 12 and build tools
sudo apt install -y build-essential gcc-12

# Set GCC 12 as default
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-12 12
sudo update-alternatives --set gcc /usr/bin/gcc-12
```

Install and Configure G++
```bash
# Install G++ 12
sudo apt install -y build-essential g++-12

# Set G++ 12 as default
sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-12 12
sudo update-alternatives --config /usr/bin/g++
```

### 4. Verify Compiler Installation

Ensure compiler versions match your kernel:
```bash
cat /proc/version
gcc --version
g++ --version
```

### 5. Desktop Environment Customization

Enable Desktop Icons
```bash
gnome-extensions enable ding@rastersoft.com
```

Add Firefox to Desktop
```bash
cp /var/lib/snapd/desktop/applications/firefox_firefox.desktop ~/Desktop/
chmod +x ~/Desktop/firefox_firefox.desktop
```

Install Ubuntu Dock Extension
```bash
sudo apt install -y gnome-shell-extension-ubuntu-dock
gnome-extensions enable ubuntu-dock@ubuntu.com
```

### 6. Configure Shell Environment

Add the following to your `~/.bashrc`:
```bash
set -o vi
export EDITOR=vim
```


### 7. Install Visual Studio Code

1. **Download VS Code**:
   - Visit: [VS Code Downloads](https://code.visualstudio.com/Download)
   - Download the `.deb` package for Ubuntu

2. **Install VS Code**:
   ```bash
   sudo apt install ./code_[VERSION]_amd64.deb
   ```

   Replace `[VERSION]` with your downloaded version number.

### 8. Create an AMI 

After verifying all functionality, go to the console:
1. Stop the instance
2. Create an AMI: **Action -> Images and Templates -> Create Image**
3. Use the custom AMI for future DCV deployments

