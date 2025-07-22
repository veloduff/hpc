# Lustre

> [!NOTE] 
> * The Lustre client packages are included with the server packages
> * ZFS is used as the backing file system, **without** LVM (see the ["Using LVM or only ZFS with Lustre"](#using-lvm-or-only-zfs-with-lustre) section for more details)

## Lustre Support matrix

https://wiki.whamcloud.com/display/PUB/Lustre+Support+Matrix


## Links

* **Creating Lustre Components**: https://wiki.lustre.org/Creating_Lustre_Object_Storage_Services_(OSS)
* **ZFS and mkfs.lustre**: https://wiki.lustre.org/ZFS_OSD_Storage_Basics
* **DKMS and kmod**:  https://klarasystems.com/articles/dkms-vs-kmod-the-essential-guide-for-zfs-on-linux/
* **Working with Lustre**: https://www.admin-magazine.com/HPC/Articles/Working-with-the-Lustre-Filesystem
* **Lustre server setup, include HA and DNE**: https://wiki.lustre.org/Lustre_Server_Requirements_Guidelines
* **Lustre Internals**: https://wiki.lustre.org/Understanding_Lustre_Internals

## Commands

`lctl get_param version`


## Disable `dnf` Subscription warning

When running the `dnf install` command, the RHEL subscription manager may check for entitlement. Here is an example:
```sh
$ dnf install ... 
Updating Subscription Management repositories.
Unable to read consumer identity

This system is not registered with an entitlement server. You can use subscription-manager to register.
```
This message can be disabled two ways:

### 1: Disable at the command line 

Add the `--disableplugin=subscription-manager` flag to your dnf/yum command:
```sh
dnf --disableplugin=subscription-manager install <package>
```

### 2: Edit the configuration file

```sh
# Set enabled=0 in the subscription-manager plugin config
sed -i 's/enabled=1/enabled=0/g' /etc/yum/pluginconf.d/subscription-manager.conf
```


## OS setup and configuration 

1. Launch instance with RHEL 8.9 (AMI: `ami-0be9dd52e05f424f3`)
2. Disable SELinux, set `SELINUX=disabled` in `/etc/selinux/config`:
4. Update:  `dnf update` (will most likely rebuild the kernel - plan on 10 - 20 mins)
5. Reboot
6. Verify SELinux is disabled:
   ```sh
   $ sestatus
   SELinux status:                 disabled
   ```


## Installing ZFS and DKMS

ZFS is the recommended backend filesystem for Lustre deployments. This guide covers installation and verification of ZFS on RHEL 8 systems.

### Prerequisites

- See "OS setup and configuration" above
- Root access to the system
- Internet connectivity for package downloads
- RHEL 8 or compatible distribution (CentOS 8, Rocky Linux 8, etc.)

### Installation Steps

#### 1. Add the EPEL Repository

EPEL (Extra Packages for Enterprise Linux) provides additional packages required for ZFS:

```sh
dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
```

#### 2. Add the ZFS Repository

The OpenZFS project maintains repositories for RHEL-based distributions:

```sh
dnf install -y https://zfsonlinux.org/epel/zfs-release-2-3$(rpm --eval "%{dist}").noarch.rpm
```

> **Note:** Check the [official OpenZFS documentation](https://openzfs.github.io/openzfs-docs/Getting%20Started/RHEL-based%20distro/index.html#rhel-based-distro) for the latest version information.

#### 3. Install ZFS Packages

Install the ZFS kernel modules and utilities:

```sh
dnf install -y kernel-devel zfs
```

This command will automatically install DKMS as a dependency. The installation process compiles the ZFS kernel modules from source, which may take several minutes to complete.

### Verify DKMS Status

Check that the ZFS modules were properly built by DKMS:

```sh
$ dkms status
zfs/2.1.16, 4.18.0-553.54.1.el8_10.x86_64, x86_64: installed
```

### Load the ZFS Kernel Module

```sh
$ modprobe -v zfs
insmod /lib/modules/4.18.0-553.54.1.el8_10.x86_64/extra/spl.ko.xz
insmod /lib/modules/4.18.0-553.54.1.el8_10.x86_64/extra/znvpair.ko.xz
insmod /lib/modules/4.18.0-553.54.1.el8_10.x86_64/extra/zcommon.ko.xz
insmod /lib/modules/4.18.0-553.54.1.el8_10.x86_64/extra/icp.ko.xz
insmod /lib/modules/4.18.0-553.54.1.el8_10.x86_64/extra/zavl.ko.xz
insmod /lib/modules/4.18.0-553.54.1.el8_10.x86_64/extra/zlua.ko.xz
insmod /lib/modules/4.18.0-553.54.1.el8_10.x86_64/extra/zzstd.ko.xz
insmod /lib/modules/4.18.0-553.54.1.el8_10.x86_64/extra/zunicode.ko.xz
insmod /lib/modules/4.18.0-553.54.1.el8_10.x86_64/extra/zfs.ko.xz
```

### Check Kernel Logs

Verify the ZFS module loaded successfully:

```sh
$ dmesg | grep -i zfs
[918.605151] ZFS: Loaded module v2.1.16-1, ZFS pool version 5000, ZFS filesystem version 5
```

### Verify ZFS Version

```sh
$ zpool version
zfs-2.1.16-1
zfs-kmod-2.1.16-1
```

### Troubleshooting

If you encounter errors like these:

```sh
$ zpool version 
The ZFS modules are not loaded. 
Try running '/sbin/modprobe zfs' as root to load them. 

$ modprobe -v zfs 
modprobe: FATAL: Module zfs not found in directory /lib/modules/4.18.0-XXXXXXXXXX
```

The issue is likely a kernel mismatch. Ensure your running kernel matches the one used to build the ZFS modules:

1. Check your current kernel: `uname -r`
2. Update `dnf update` the OS and reboot
3. Reboot if you've updated the kernel but haven't rebooted


## Install Lustre

### 1. Setup the Lustre repo (version 2.15.4 shown here)

In the `/etc/yum.repos.d` directory, create the `lustre.repo` file with this:
```sh
[lustre-server]
name=lustre-server
baseurl=https://downloads.whamcloud.com/public/lustre/lustre-2.15.4/el8.9/server/
exclude=*debuginfo*
enabled=0
gpgcheck=0
```

### 2. Enable CodeReady Linux Builder repository

Enable CodeReady Linux Builder repository for packages `libmount-devel` and `libyaml-devel`.

For this command below, the "Unable to read consumer identity" and entitlement messages can be 
ignored.  See the section below "Disable `dnf` subscription warning".

```sh
$ dnf config-manager --set-enabled codeready-builder-for-rhel-8-rhui-rpms
```


### 3. Clean the repository cache

```sh
$ dnf clean all
```

### 4. Install the Lustre server, it takes some time to build the Lustre (DKMS) kernel module (`lustre-zfs-dkms`)
   
```sh
$ dnf --enablerepo=lustre-server install lustre-dkms lustre-osd-zfs-mount lustre
```

### 5. Load the kernel module

```sh
$ modprobe -v lustre
insmod /lib/modules/4.18.0-553.54.1.el8_10.x86_64/kernel/net/sunrpc/sunrpc.ko.xz
insmod /lib/modules/4.18.0-553.54.1.el8_10.x86_64/extra/libcfs.ko.xz
insmod /lib/modules/4.18.0-553.54.1.el8_10.x86_64/extra/lnet.ko.xz
insmod /lib/modules/4.18.0-553.54.1.el8_10.x86_64/extra/obdclass.ko.xz
insmod /lib/modules/4.18.0-553.54.1.el8_10.x86_64/extra/ptlrpc.ko.xz
insmod /lib/modules/4.18.0-553.54.1.el8_10.x86_64/extra/fld.ko.xz
insmod /lib/modules/4.18.0-553.54.1.el8_10.x86_64/extra/fid.ko.xz
insmod /lib/modules/4.18.0-553.54.1.el8_10.x86_64/extra/osc.ko.xz
insmod /lib/modules/4.18.0-553.54.1.el8_10.x86_64/extra/lov.ko.xz
insmod /lib/modules/4.18.0-553.54.1.el8_10.x86_64/extra/mdc.ko.xz
insmod /lib/modules/4.18.0-553.54.1.el8_10.x86_64/extra/lmv.ko.xz
insmod /lib/modules/4.18.0-553.54.1.el8_10.x86_64/extra/lustre.ko.xz
```

### 6. Verify Lustre install 

Check kernel logs
```sh
$ dmesg | tail -3
[ 3578.308629] Lustre: Lustre: Build Version: 2.15.4
[ 3578.434714] LNet: Added LNI 172.25.18.117@tcp [8/256/0/180]
[ 3578.435640] LNet: Accept secure, port 988
```

Also check with `lsmod`:
```sh
$ lsmod | egrep -i "zfs|lustre"
lustre               1052672  0
lmv                   208896  1 lustre
mdc                   286720  1 lustre
lov                   344064  2 mdc,lustre
ptlrpc               2494464  7 fld,osc,fid,lov,mdc,lmv,lustre
obdclass             3633152  8 fld,osc,fid,ptlrpc,lov,mdc,lmv,lustre
lnet                  716800  6 osc,obdclass,ptlrpc,ksocklnd,lmv,lustre
libcfs                266240  11 fld,lnet,osc,fid,obdclass,ptlrpc,ksocklnd,lov,mdc,lmv,lustre
zfs                  3911680  0
zunicode              335872  1 zfs
zzstd                 520192  1 zfs
zlua                  180224  1 zfs
zavl                   16384  1 zfs
icp                   319488  1 zfs
zcommon               102400  2 zfs,icp
znvpair                90112  2 zfs,zcommon
spl                   118784  6 zfs,icp,zzstd,znvpair,zcommon,zavl
```

Check ping and NIDS with `lctl`:
```sh
$ lctl
lctl > ping 172.31.13.182
12345-0@lo
12345-172.31.13.182@tcp

lctl > list_nids
172.31.13.182@tcp
```


## Create the Lustre file system

There is an option of using one command (`mkfs.lustre`) or two commands (`mkfs.lustre` and `zpool create`) when creating 
Lustre components. For production systems, the `zpool create` command, followed by the `mkfs.lustre` command should 
be used. This allows for failover configuration to be setup using the `zpool create` command.

> [!NOTE] From the Lustre docs:
> For high-availability configurations where the ZFS volumes are kept on shared storage, the zpools must be 
> created independently of the mkfs.lustre command in order to be able to correctly prepare the zpools for 
> use in a high-availability, failover environment.

### 0. Verify that ZFS and Lustre modules are loaded

```sh
$ lsmod | egrep -i "zfs|lustre"
```


### 1. Create MGT using ZFS backend

The MGT is critical to the file system, and should use a redundant disk strategy. For this example, a
mirror will be used for the ZFS pool.

**Create the pool**:

```sh 
zpool create -O canmount=off -o cachefile=none mgspool mirror /dev/nvmeXnY /dev/nvmeAnB
```

**Create the MGS** 

This command **formats an MGT** used for MGS storage. For the MGS creation, the first IP address is usually 
the host that the command is being run from. The <zfs_pool>/<dataset> are `mgspool/mgt` for this command.

```sh
mkfs.lustre --mgs --backfstype=zfs mgspool/mgt
```


### 2. Create an MDT for each file system

```sh 
# Create the pool(s):
zpool create -O canmount=off -o cachefile=none mdtpool0 /dev/nvmeXnY   # testfs01
zpool create -O canmount=off -o cachefile=none mdtpool1 /dev/nvmeXnY   # testfs02
...

# Create the MDT 
mkfs.lustre --mdt --backfstype=zfs --fsname=testfs --index=0 --mgsnode=<mgs-hostname> mdtpool0/mdt0
mkfs.lustre --mdt --backfstype=zfs --fsname=testfs --index=1 --mgsnode=<mgs-hostname> mdtpool1/mdt1
```


### 3. Create the OSTs 

```sh
# Create the pool:
zpool create -O canmount=off -o cachefile=none ostpool0 /dev/nvmeXnY 
zpool create -O canmount=off -o cachefile=none ostpool1 /dev/nvmeXnY 
# ... repeat for all OSTs

# Create the OST - for each OST 
mkfs.lustre --ost --backfstype=zfs --fsname=testfs --index=0 --mgsnode=<mgs-hostname> ostpool0/ost0
mkfs.lustre --ost --backfstype=zfs --fsname=testfs --index=1 --mgsnode=<mgs-hostname> ostpool1/ost1
# ... repeat for all OSTs
```


## Mounting Lustre Components (starting the file system)

For the Lustre file system, mounting the file system components is the same as "starting" the file system.

### 1. Mount the MGS (Management Server)

> [!NOTE] The MGT mount and only needs to be don on the MGS node

```sh
# Create mount point directory
mkdir -p /lustre/mgt

# Mount the MGS
mount -t lustre mgspool/mgt /lustre/mgt
```

### 3. Create a mount point specfic to the file system 

```sh
mkdir /lustre/testfs
```

### 2. Mount the MDT (Metadata Target)

> [!NOTE] The MDT mount and only needs to be don on the MDS node

```sh
# Create mount point directory that is specific to the file system
mkdir /lustre/testfs/mdt0

# Mount the MDT
mount -t lustre mdtpool0/mdt0 /lustre/testfs/mdt0
```

### 3. Mount the OSTs (Object Storage Targets)

```sh
# Create mount point directories
mkdir /lustre/testfs/ost0
mkdir /lustre/testfs/ost1
# ... repeat for all OSTs

# Mount the OSTs
mount -t lustre ostpool0/ost0 /lustre/testfs/ost0
mount -t lustre ostpool1/ost1 /lustre/testfs/ost1
# ... repeat for all OSTs
```

### 4. Mount the Lustre filesystem on a client

```sh
# Create client mount point
mkdir /mnt/lustre

# Mount the filesystem (specify MGS node)
mount -t lustre ip-172-25-18-117@tcp:/testfs /mnt/lustre
```

### 5. Verify the mounts

```sh
# Check if all components are mounted
$ mount | grep lustre
mgspool/mgt on /lustre/mgt type lustre (ro,svname=MGS,nosvc,mgs,osd=osd-zfs)
mdtpool0/mdt0 on /lustre/testfs/mdt0 type lustre (ro,svname=testfs-MDT0000,mgsnode=172.31.26.176@tcp,osd=osd-zfs)
ostpool0/ost0 on /lustre/testfs/ost0 type lustre (ro,svname=testfs-OST0000,mgsnode=172.31.26.176@tcp,osd=osd-zfs)
172.31.26.176@tcp:/testfs on /mnt/lustre type lustre (rw,checksum,flock,nouser_xattr,lruresize,lazystatfs,nouser_fid2path,verbose,encrypt)


# Display Lustre filesystem status
$ lfs df -h
UUID                       bytes        Used   Available Use% Mounted on
testfs-MDT0000_UUID         1.7G        3.0M        1.7G   1% /mnt/lustre[MDT:0]
testfs-OST0000_UUID         7.2G        3.0M        7.2G   1% /mnt/lustre[OST:0]

filesystem_summary:         7.2G        3.0M        7.2G   1% /mnt/lustre
```

### 6. Run simple test 

```sh
$ dd if=/dev/zero of=/mnt/lustre/file.10G bs=1M count=10000
10000+0 records in
10000+0 records out
10485760000 bytes (10 GB, 9.8 GiB) copied, 69.5743 s, 151 MB/s
```

## Delete ZFS datasets and pools 

**Destroy all datasets in the pool**
```sh
zfs destroy -r mgt
```

**Destroy the pool**
```sh
zpool destroy mgt
```


## Using LVM or only ZFS with Lustre

There is an option to use LVM as part of the Lustre file system stack:

* With LVM:  Physical disk -> **LVM** -> ZFS -> Lustre
* Direct, without LVM: Physical disk -> ZFS -> Lustre

Typical Lustre deployments prefer the direct approach (`Physical disk -> ZFS -> Lustre`) as it simplifies the 
stack while still providing the necessary redundancy and management features through ZFS.

### ZFS vs LVM Functionality Comparison

#### Shared Functionality
- **Volume Management**: Both can manage multiple physical disks as logical volumes
- **Resizing**: Both allow expanding storage pools/volumes
- **Snapshots**: Both support point-in-time snapshots
- **Device Pooling**: Both can combine multiple physical devices into a single logical unit
- **Thin Provisioning**: Both support allocating space on demand

#### ZFS Advantages Over LVM
- **Integrated RAID**: ZFS has built-in RAID functionality (RAIDZ1/2/3) without needing mdadm
- **Data Integrity**: ZFS includes checksumming and self-healing capabilities
- **Copy-on-Write**: ZFS uses CoW for better data protection and snapshot efficiency
- **Compression**: ZFS has native transparent compression
- **Deduplication**: ZFS can eliminate duplicate data blocks
- **Send/Receive**: ZFS has built-in replication capabilities
- **Single Layer**: ZFS combines volume management and filesystem in one layer

### Why use LVM with ZFS in Lustre?
- When you need multiple devices per Lustre target
- When you need to expand storage later

For most Lustre deployments, using ZFS directly without LVM is preferred because:
1. It eliminates a redundant layer
2. Reduces complexity
3. Improves performance
4. Avoids conflicting redundancy mechanisms
5. ZFS already provides most functionality that would be needed from LVM

This is why the direct approach (`Physical disk -> ZFS -> Lustre`) is typically recommended for Lustre deployments.



## Create Lustre components examples

### Using both `zpool create` and `mkfs.lustre`

```
# Create the zpool
zpool create -O canmount=off -o cachefile=none mgspool mirror /dev/sda /dev/sdc

# Format the Lustre MGT 
mkfs.lustre --mgs --servicenode 192.168.227.11@tcp1 --servicenode 192.168.227.12@tcp1 --backfstype=zfs mgspool/mgt
```

### Using only `mkfs.lustre`

```
mkfs.lustre --mgs --servicenode 192.168.227.11@tcp1 --servicenode 192.168.227.12@tcp1 --backfstype=zfs mgspool/mgt mirror /dev/sda /dev/sdc
```

Exaplanation of options used for the `zpool create` command:

* `-O canmount=off`: This property prevents the ZFS filesystem from being automatically mounted. This is important in a Lustre setup because:
   * You don't want ZFS to automatically mount the filesystem
   * Lustre will handle the mounting instead
   * It prevents conflicts between ZFS's native mounting and Lustre's mounting mechanisms
* `-o cachefile=none`: This prevents ZFS from caching the pool configuration, which means the pool won't be automatically imported at boot time
