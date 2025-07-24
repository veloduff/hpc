# IBM Spectrum Scale (GPFS) Documentation

Documentation and resources for installing, configuring, and managing IBM Spectrum Scale (formerly GPFS) on cluster environments.

## Prerequisites

This guide assumes that your cluster has the following components properly configured:
- `pdsh` (parallel distributed shell) for both the EC2 user account and root account
- `pdcp` (parallel distributed copy) for both the EC2 user account and root account
- All cluster nodes have the same architecture (this example uses Intel x86_64)

> [!WARNING]
> **Important Architecture Requirement**: The steps below assume that the architecture on the HeadNode is identical to the compute nodes. This example is specifically designed for Intel x86_64 architecture.

### Disk Preparation

Before creating a file system, all disks must be available as raw block devices without any existing file systems, partitions, or logical volumes. 

**Reference**: For detailed disk preparation instructions, please refer to **[Storage Management](../Storage_Management/)** in this repository.

## IBM Spectrum Scale Installation Process

### Step 1: Download and Extract GPFS Packages

1. **Download the installation package**:
   - Navigate to the IBM Spectrum Scale website: https://www.ibm.com/products/storage-scale
   - Select **Pricing plans** → **Try the free edition**
   - Download the appropriate installation package for your architecture

2. **Upload and extract the installation file**:
   
   Upload the downloaded zip file to your head node and extract it:
   ```bash
   unzip Storage_Scale_Developer-5.2.2.1-x86_64-Linux.zip
   ```
   
   Expected output:
   ```
   Archive:  Storage_Scale_Developer-5.2.2.1-x86_64-Linux.zip
     inflating: Storage_Scale_Developer-5.2.2.1-x86_64-Linux.README
     inflating: Storage_Scale_Developer-5.2.2.1-x86_64-Linux-install
     inflating: Storage_Scale_Developer-5.2.2.1-x86_64-Linux-install.md5
     inflating: Storage_Scale_public_key.pgp
   ```

3. **Verify the installation file integrity**:
   
   Check the MD5 checksum to ensure file integrity:
   ```bash
   md5sum Storage_Scale_Developer-5.2.2.1-x86_64-Linux-install
   cat Storage_Scale_Developer-5.2.2.1-x86_64-Linux-install.md5
   ```
   
   Both commands should return the same MD5 hash:
   ```
   be0855301acdbf551ace695d6fca6684  Storage_Scale_Developer-5.2.2.1-x86_64-Linux-install
   be0855301acdbf551ace695d6fca6684  Storage_Scale_Developer-5.2.2.1-x86_64-Linux-install
   ```

4. **Execute the installation extractor**:
   
   Make the installer executable and run it with silent mode to automatically handle license agreements:
   ```bash
   chmod 755 Storage_Scale_Developer-5.2.2.1-x86_64-Linux-install
   sudo ./Storage_Scale_Developer-5.2.2.1-x86_64-Linux-install --silent
   ```
   
   Expected output:
   ```
   Extracting License Acceptance Process Tool to /usr/lpp/mmfs/5.2.2.1 ...
   (additional output truncated for brevity)
   ```

5. **Verify package extraction**:
   
   Confirm that all RPM packages have been extracted successfully:
   ```bash
   ls -1 /usr/lpp/mmfs/5.2.2.1/gpfs_rpms/
   ```
   
   Expected package list (version 5.2.2.1):
   ```
   gpfs.adv-5.2.2-1.x86_64.rpm
   gpfs.afm.cos-1.2.2-1.x86_64.rpm
   gpfs.base-5.2.2-1.x86_64.rpm
   gpfs.compression-5.2.2-1.x86_64.rpm
   gpfs.crypto-5.2.2-1.x86_64.rpm
   gpfs.docs-5.2.2-1.noarch.rpm
   gpfs.gpl-5.2.2-1.noarch.rpm
   gpfs.gskit-8.0.55-19.1.x86_64.rpm
   gpfs.gui-5.2.2-1.noarch.rpm
   gpfs.java-5.2.2-1.x86_64.rpm
   gpfs.license.dev-5.2.2-1.x86_64.rpm
   gpfs.msg.en_US-5.2.2-1.noarch.rpm
   repodata
   rhel8
   rhel9
   sles15
   ```

### Step 2: Install Performance Tools Across the Cluster

Install network performance testing tools on all cluster nodes:
```bash
pdsh sudo yum -y install iperf3
```

### Step 3: Install Prerequisite Packages

**Important**: Install these packages **only on the HeadNode**. They are required for building the GPFS GPL RPM:

```bash
sudo yum -y install ksh kernel-devel cpp gcc gcc-c++ rpm-build kernel-headers elfutils-libelf-devel binutils
sudo yum -y install "kernel-devel-uname-r == $(uname -r)"
```

### Step 4: Install GPFS on Head Node

Initially, install GPFS only on the HeadNode to enable GPL RPM compilation:

```bash
cd /usr/lpp/mmfs/5.2.2.1/gpfs_rpms/
sudo yum -y install gpfs.adv*rpm gpfs.base*rpm gpfs.gpl*rpm gpfs.license.dev*rpm gpfs.gskit*rpm gpfs.msg*rpm
```

**Verify the installation**:
```bash
rpm -qa | grep gpfs
```

Expected output:
```
gpfs.base-5.2.2-1.x86_64
gpfs.msg.en_US-5.2.2-1.noarch
gpfs.adv-5.2.2-1.x86_64
gpfs.gpl-5.2.2-1.noarch
gpfs.gskit-8.0.55-19.1.x86_64
gpfs.license.dev-5.2.2-1.x86_64
```

### Step 5: Build GPFS GPL RPM

The GPL RPM must be built after installing the GPFS packages and prerequisite packages:

```bash
cd /usr/lpp/mmfs/bin
sudo ./mmbuildgpl --build-package -v
```

Upon successful completion, you should see output similar to:
```
Wrote: /root/rpmbuild/RPMS/x86_64/gpfs.gplbin-4.18.0-553.46.1.el8_10.x86_64-5.2.2-1.x86_64.rpm
--------------------------------------------------------
mmbuildgpl: Building GPL module completed successfully at Thu Apr 17 17:25:45 UTC 2025.
--------------------------------------------------------
```

### Step 6: Distribute RPMs to Compute Nodes

Create a shared location accessible by all cluster nodes for the GPFS RPM packages:

1. **Create installation directory** (as EC2 user, e.g., `ec2-user` for Amazon Linux and RHEL):
   ```bash
   cd ~
   mkdir gpfs_install
   ```

2. **Copy GPFS RPMs to shared location**:
   ```bash
   cd /usr/lpp/mmfs/5.2.2.1/gpfs_rpms/
   
   cp gpfs.adv-5.2.2-1.x86_64.rpm \
      gpfs.base-5.2.2-1.x86_64.rpm \
      gpfs.gpl-5.2.2-1.noarch.rpm \
      gpfs.gskit-8.0.55-19.1.x86_64.rpm \
      gpfs.license.dev-5.2.2-1.x86_64.rpm \
      gpfs.msg.en_US-5.2.2-1.noarch.rpm \
      ~/gpfs_install/
   ```

3. **Copy the compiled GPL RPM**:
   ```bash
   sudo cp /root/rpmbuild/RPMS/x86_64/gpfs.gplbin-4.18.0-553.46.1.el8_10.x86_64-5.2.2-1.x86_64.rpm ~/gpfs_install/
   ```

### Step 7: Install GPFS Across the Cluster

Install GPFS on all compute nodes using parallel distributed shell:

```bash
pdsh "cd ~/gpfs_install && sudo yum -y install gpfs.adv*rpm gpfs.base*rpm gpfs.gpl*rpm gpfs.license.dev*rpm gpfs.gskit*rpm gpfs.msg*rpm"
```

**Verify cluster-wide installation**:
```bash
pdsh "rpm -qa | grep gpfs | sort" | dshbak -c
```

Expected output:
```
----------------
queue1-st-compute-[1-4]
----------------
gpfs.adv-5.2.2-1.x86_64
gpfs.base-5.2.2-1.x86_64
gpfs.gpl-5.2.2-1.noarch
gpfs.gplbin-4.18.0-553.46.1.el8_10.x86_64-5.2.2-1.x86_64
gpfs.gskit-8.0.55-19.1.x86_64
gpfs.license.dev-5.2.2-1.x86_64
gpfs.msg.en_US-5.2.2-1.noarch
```

## GPFS Cluster Configuration

### Step 8: Create the GPFS Cluster

**Important**: The GPFS cluster nodes (nodes that mount or serve the file system) should **not** include the HeadNode. Include only the dedicated storage and compute nodes.

1. **Switch to root account and connect to a storage node**:
   ```bash
   sudo /bin/su -
   ssh storage-node01
   ```

2. **Create cluster node definition file**:
   
   Create a file named `gpfs.nodes` with the following format:
   ```bash
   cat > gpfs.nodes << EOF
   storage-node01:manager-quorum
   storage-node02:manager-quorum
   storage-node03:quorum
   storage-node04
   compute01
   compute02
   compute03
   compute04
   EOF
   ```

3. **Create the GPFS cluster**:
   ```bash
   mmcrcluster -N gpfs.nodes --ccr-enable -r /usr/bin/ssh -R /usr/bin/scp -C gpfs1 -A
   ```

4. **Verify cluster creation**:
   ```bash
   mmlscluster
   ```
   
   Expected output:
   ```
   GPFS cluster information
   ========================
     GPFS cluster name:         gpfs1.test-cluster
     GPFS cluster id:           1111111111111111111 
     GPFS UID domain:           gpfs1.test-cluster
     Remote shell command:      /usr/bin/ssh
     Remote file copy command:  /usr/bin/scp
     Repository type:           CCR

    Node  Daemon node name                  IP address   Admin node name                   Designation
   ---------------------------------------------------------------------------------------------------
      1   queue1-st-t2micro-1.test-cluster  10.0.0.1     queue1-st-t2micro-1.test-cluster  quorum-manager
      2   queue1-st-t2micro-2.test-cluster  10.0.0.2     queue1-st-t2micro-2.test-cluster  quorum-manager
      3   queue1-st-t2micro-3.test-cluster  10.0.0.3     queue1-st-t2micro-3.test-cluster  quorum
      4   queue1-st-t2micro-4.test-cluster  10.0.0.4     queue1-st-t2micro-4.test-cluster
   ```

### Step 9: Accept Licenses and Start GPFS

1. **Accept licenses across the cluster**:
   ```bash
   mmchlicense server --accept -N all
   ```

2. **Verify license acceptance**:
   ```bash
   mmlslicense
   ```
   
   Expected output:
   ```
    Summary information
   ---------------------
   Number of nodes defined in the cluster:                          4
   Number of nodes with server license designation:                 4
   Number of nodes with FPO license designation:                    0
   Number of nodes with client license designation:                 0
   Number of nodes still requiring server license designation:      0
   Number of nodes still requiring client license designation:      0
   This node runs IBM Storage Scale Developer Edition 
   ```

3. **Start GPFS services across the cluster**:
   ```bash
   mmstartup -a
   ```

4. **Verify cluster state**:
   ```bash
   mmgetstate -asL
   ```
   
   Expected output:
   ```
    Node number  Node name            Quorum  Nodes up  Total nodes  GPFS state    Remarks
   -------------------------------------------------------------------------------------------
              1  queue1-st-t2micro-1     2         4          4      active        quorum node
              2  queue1-st-t2micro-2     2         4          4      active        quorum node
              3  queue1-st-t2micro-3     2         4          4      active        quorum node
              4  queue1-st-t2micro-4     2         4          4      active

    Summary information
   ---------------------
   Number of nodes defined in the cluster:            4
   Number of local nodes active in the cluster:       4
   Number of remote nodes joined in this cluster:     0
   Number of quorum nodes defined in the cluster:     3
   Number of quorum nodes active in the cluster:      3
   Quorum = 2, Quorum achieved
   ```

## Network Shared Disk (NSD) Configuration

### Step 10: Create NSDs

Before creating NSDs, ensure that all devices are raw block devices without partitions or logical volumes. Refer to the **Disk Management** guide for detailed preparation instructions.

1. **Create NSD stanza file**:
   
   The `mmcrnsd` command requires an **NSD stanza file**. Create a file named `gpfs.nsds`:
   ```bash
   cat > gpfs.nsds << EOF
   %nsd: device=/dev/nvme1n1 nsd=nsd1 servers=queue1-st-t2micro-1 usage=dataAndMetadata failureGroup=100 pool=system
   %nsd: device=/dev/nvme1n1 nsd=nsd2 servers=queue1-st-t2micro-2 usage=dataAndMetadata failureGroup=200 pool=system
   %nsd: device=/dev/nvme1n1 nsd=nsd3 servers=queue1-st-t2micro-3 usage=dataAndMetadata failureGroup=300 pool=system
   %nsd: device=/dev/nvme1n1 nsd=nsd4 servers=queue1-st-t2micro-4 usage=dataAndMetadata failureGroup=400 pool=system
   EOF
   ```

2. **Create NSDs using the stanza file**:
   ```bash
   mmcrnsd -F gpfs.nsds
   ```

3. **Verify NSD creation**:
   ```bash
   mmlsnsd -aX
   ```
   
   Expected output:
   ```
    Disk name       NSD volume ID      Device          Devtype  Node name or Class       Remarks
   -------------------------------------------------------------------------------------------------------
    nsd1            1111111111111111   /dev/nvme1n1    generic  queue1-st-t2micro-1      server node
    nsd2            1111111111111111   /dev/nvme1n1    generic  queue1-st-t2micro-2      server node
    nsd3            1111111111111111   /dev/nvme1n1    generic  queue1-st-t2micro-3      server node
    nsd4            1111111111111111   /dev/nvme1n1    generic  queue1-st-t2micro-4      server node
   ```

## File System Creation and Mounting

### Step 11: Create and Mount the File System

1. **Create the file system**:
   
   Use the `mmcrfs` command with the NSD stanza file to create the file system:
   ```bash
   mmcrfs gpfs1 -F gpfs.nsds -B 1M -j cluster -n <number_of_clients>
   ```
   
   Expected output:
   ```
   The following disks of gpfs1 will be formatted on node storage-node01:
       nsd1: size 226020 MB
       nsd2: size 226020 MB
       nsd3: size 226020 MB
       nsd4: size 226020 MB
   Formatting file system ...
   Disks up to size 2.06 TB can be added to storage pool system.
   Creating Inode File
   Creating Allocation Maps
   Creating Log Files
   Clearing Inode Allocation Map
   Clearing Block Allocation Map
   Formatting Allocation Map for storage pool system
   Completed creation of file system /dev/gpfs1.
   mmcrfs: Propagating the cluster configuration data to all
     affected nodes.  This is an asynchronous process.
   ```

2. **Verify file system creation**:
   ```bash
   mmlsfs all
   ```

3. **Mount the file system**:
   ```bash
   mmmount all -a
   ```

4. **Verify file system mounting**:
   
   Using GPFS-specific command:
   ```bash
   mmlsmount all -L
   ```
   
   Expected output:
   ```
   File system gpfs1 is mounted on 4 nodes:
     10.0.0.1      queue1-st-t2micro-1
     10.0.0.2      queue1-st-t2micro-2
     10.0.0.3      queue1-st-t2micro-3
     10.0.0.4      queue1-st-t2micro-4
   ```
   
   Using standard Linux command:
   ```bash
   df -hT -t gpfs
   ```
   
   Expected output:
   ```
   Filesystem     Type  Size  Used Avail Use% Mounted on
   gpfs1          gpfs  883G  2.5G  881G   1% /gpfs/gpfs1
   ```

### Step 12: Verify File System Configuration

Use the `mmdf` command to display detailed disk information for the NSDs in the file system:

```bash
mmdf gpfs1 --block-size G
```

Expected output:
```
disk                disk size  failure holds    holds           free in GB          free in GB
name                    in GB    group metadata data        in full blocks        in fragments
--------------- ------------- -------- -------- ----- -------------------- -------------------
Disks in storage pool: system (Maximum disk size allowed is 2.06 TB)
nsd1                      221      100 yes      yes             221 (100%)             1 ( 0%)
nsd3                      221      300 yes      yes             221 (100%)             1 ( 0%)
nsd2                      221      200 yes      yes             221 (100%)             1 ( 0%)
nsd4                      221      400 yes      yes             221 (100%)             1 ( 0%)
                -------------                         -------------------- -------------------
(pool total)              883                                   881 (100%)             1 ( 0%)

                =============                         ==================== ===================
(total)                   883                                   881 (100%)             1 ( 0%)

Inode Information
-----------------
Number of used inodes:            4014
Number of free inodes:          496722
Number of allocated inodes:     500736
Maximum number of inodes:       904192
```

## GPFS File System Monitoring

### Monitoring Tools and Techniques

#### 1. GCAM (GPFS Cluster Analysis and Monitoring)
For advanced monitoring capabilities, consider using GCAM:
- **Repository**: https://github.com/impredicative/gcam
- **Purpose**: Provides comprehensive cluster analysis and monitoring features

#### 2. NMON (System Performance Monitor)
NMON provides real-time system performance monitoring with GPFS-specific metrics:

**Launch NMON with automatic disk grouping**:
```bash
nmon -g auto
```

**Interactive usage**:
- Press `g` to view disk groups
- Monitor I/O performance, throughput, and system utilization

**Example NMON output**:
```
┌nmon─16p─────────────────────Hostname=queue1-st-t2mRefresh= 2secs ───16:08.02─────────────────┐
│ Disk Group I/O ──────────────────────────────────────────────────────────────────────────────│
│ Name          Disks AvgBusy Read-KB/s|Write  TotalMB/s   xfers/s BlockSizeKB                 │
│ nvme1n1            1   0.0%       0.0|0.0          0.0       0.0    0.0                      │
│ nvme0n1            1   0.0%       0.0|0.0          0.0       0.0    0.0                      │
│ Groups= 2 TOTALS   2   0.0%       0.0|0.0          0.0       0.0                             │
│──────────────────────────────────────────────────────────────────────────────────────────────│
```

#### 3. Built-in GPFS Monitoring Commands

**Monitor cluster state**:
```bash
mmgetstate -a
```

**Monitor file system usage**:
```bash
mmdf <filesystem_name>
```

**Monitor I/O statistics**:
```bash
mmfsadm dump iohist
```

**Monitor active operations**:
```bash
mmfsadm dump waiters
```

## Key Commands Reference

### Cluster Management
```bash
# Check cluster state
mmgetstate -asL

# List cluster configuration
mmlscluster

# Start/stop GPFS services
mmstartup -a
mmshutdown -a
```

### File System Operations
```bash
# List file systems
mmlsfs all

# Mount/unmount file systems
mmmount all -a
mmumount all -a

# Check file system usage
mmdf <filesystem_name>
```

### NSD Management
```bash
# List NSDs
mmlsnsd -aX

# Create NSDs from stanza file
mmcrnsd -F <stanza_file>
```

### Monitoring Commands
```bash
# Monitor I/O statistics
mmfsadm dump iohist

# Monitor active operations
mmfsadm dump waiters

# Launch NMON for real-time monitoring
nmon -g auto
```

## Troubleshooting Common Issues

### Issue 1: GPL RPM Build Failures
- **Cause**: Missing kernel development packages
- **Solution**: Ensure all prerequisite packages are installed before building GPL RPM

### Issue 2: Cluster Communication Problems
- **Cause**: SSH connectivity issues between nodes
- **Solution**: Verify SSH key-based authentication is configured properly

### Issue 3: NSD Creation Failures
- **Cause**: Devices have existing partitions or file systems
- **Solution**: Clean devices using the Disk Management procedures

### Issue 4: Mount Failures
- **Cause**: GPFS services not running on all nodes
- **Solution**: Use `mmgetstate -a` to verify all nodes are active

## Best Practices

1. **Regular Monitoring**: Implement continuous monitoring using NMON and GCAM
2. **Backup Strategy**: Establish regular backup procedures for critical data
3. **Performance Tuning**: Monitor I/O patterns and adjust block sizes accordingly
4. **Capacity Planning**: Monitor disk usage and plan for expansion before reaching capacity limits
5. **Security**: Implement proper access controls and authentication mechanisms

## Configuration Files

### Essential Configuration Files
- **gpfs.nodes** - Cluster node definition file
- **gpfs.nsds** - Network Shared Disk stanza file

### Sample Node Definition (gpfs.nodes)
```
storage-node01:manager-quorum
storage-node02:manager-quorum
storage-node03:quorum
storage-node04
compute01
compute02
compute03
compute04
```

### Sample NSD Stanza (gpfs.nsds)
```
%nsd: device=/dev/nvme1n1 nsd=nsd1 servers=storage-node01 usage=dataAndMetadata failureGroup=100 pool=system
%nsd: device=/dev/nvme1n1 nsd=nsd2 servers=storage-node02 usage=dataAndMetadata failureGroup=200 pool=system
%nsd: device=/dev/nvme1n1 nsd=nsd3 servers=storage-node03 usage=dataAndMetadata failureGroup=300 pool=system
%nsd: device=/dev/nvme1n1 nsd=nsd4 servers=storage-node04 usage=dataAndMetadata failureGroup=400 pool=system
```

## Additional Resources

### Related Documentation
- **Storage Management** - Disk preparation and management procedures
- **Benchmarking** - Performance testing and optimization guides
- **Cluster Setup** - General cluster configuration documentation

### External Resources
- [IBM Spectrum Scale Documentation](https://www.ibm.com/docs/en/spectrum-scale)
- [GCAM GitHub Repository](https://github.com/impredicative/gcam)
- [IBM Spectrum Scale Community](https://community.ibm.com/community/user/storage/communities/community-home?CommunityKey=6b8b4c8b-7f7e-4b8a-9b0a-8b7f7e4b8a9b)

## Support and Troubleshooting

For issues not covered in this documentation:
1. Check the troubleshooting section above for common solutions
2. Review IBM Spectrum Scale official documentation
3. Check GPFS system logs for detailed error information
4. Consult the archived installation script for reference

---

**Note**: This documentation is specifically designed for IBM Spectrum Scale Developer Edition in cluster environments. For production deployments, consult IBM's official documentation and consider professional support services.
