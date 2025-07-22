# Setting Up a Lustre Cluster on AWS

This guide walks through the process of setting up a Lustre parallel file system cluster on AWS using ParallelCluster and custom scripts.

## Prerequisites

- AWS ParallelCluster installed and configured
- AWS CLI with appropriate credentials
- SSH key pair for EC2 access
- VPC with appropriate subnets in different availability zones
- Custom AMI with ZFS and Lustre server pre-installed

## Launch the cluster

### Configure the ParallelCluster launch file (YAML file)

1. Use the provided `pcluster_lustre.yaml` template as a base configuration:
   - Configures a head node and multiple compute queues
   - Sets up storage nodes for MGS (Management Server), MDS (Metadata Server), and OSS (Object Storage Servers)
   - Defines instance types and networking configuration

2. Customize the configuration by updating the `pcluster_lustre.yaml` file, for example:
   ```yaml
   Region: <your-region>
   Image:
     Os: rhel8
     CustomAmi: <your-custom-ami>  # AMI with ZFS and Lustre
   HeadNode:
     InstanceType: <HeadNode-instance-type>
     Ssh:
       KeyName: <your-key-name>
     Networking:
       SubnetId: <your-subnet-id>
       ComputeResources:
   ...
   Scheduling:
     Scheduler: slurm
     SlurmQueues:
     - Name: storage-mgs-mds
       ...
       ComputeResources:
       - Name: storage-mgs-mds
         InstanceType: <batch-instance-type>
   
   ```

### Launch the cluster

Using the process documented in the [Cluster Setup README.md](../Cluster_Setup/README.md), create the cluster 
with the customized YAML file from the previous step. Specifically, complete the entire **ParallelCluster** section.

Do not proceed to the next step until the cluster is launched, configured, pdsh is working across the cluster,
and the MPI has been tested. 

### Set Up Host Resolution

1. Copy the [fix_lustre_hosts_file.sh](fix_lustre_hosts_file.sh) host file configuration script on to the head node and run: 
   ```bash
   chmod +x fix_lustre_hosts_file.sh
   ./fix_lustre_hosts_file.sh
   ```

2. Update `/etc/hosts` on the head node with the output from `fix_lustre_hosts_file.sh`, be careful not to remove the host 
   entry for the head node (at the top of /etc/hosts)

3. Distribute the updated /etc/hosts file the cluster
   ```bash
   sudo /bin/su - -c "pdcp /etc/hosts /etc/hosts"
   ```

### Configure host file groups to use with pdsh

1. Copy the [create_lustre_pdsh_files.sh](create_lustre_pdsh_files.sh) file on to the head node and run:
   ```bash
   chmod +x create_lustre_pdsh_files.sh
   ./create_lustre_pdsh_files.sh
   ```

   This creates these pdsh cluster files:
   - `cluster.all`: All nodes
   - `cluster.oss`: Object Storage Server nodes
   - `cluster.mgs`: Management Server node
   - `cluster.mds`: Metadata Server nodes

2. Configure root host files and distribute /etc/hosts

   ```bash
   # Switch to root user
   sudo /bin/su -
   
   # Copy cluster files just created to root's home directory
   cp ~ec2-user/cluster.* .
   
   # Distribute /etc/hosts file to all nodes
   pdcp /etc/hosts /etc/hosts

   # Update WCOLL variable in .bash_profile
   sed -i 's/export WCOLL=.*cluster[^\/]*/export WCOLL=$HOME\/cluster.all/' $HOME/.bash_profile
   
   # Exit root shell
   exit
   ```

## Create EBS volume management script

The `setup_lustre.sh` script (seen the next step) uses the [ebs_create_attach.sh](../Storage_Management/ebs_create_attach.sh)
helper script to create and attache EBS volumes on the Lustre servers.

There are few options that can be changed in `Default values`.

Copy, **but do not run**, the [ebs_create_attach.sh](../Storage_Management/ebs_create_attach.sh) file on to the head node, and set execute bit:
```bash
chmod +x ebs_create_attach.sh
```

## Configure a Lustre File System

At this point, the cluster should be configured and the files should be in place to create the file system.

### Create a Lustre file system 

1. Copy, **but do not run**, the [setup_lustre.sh](setup_lustre.sh) file on to the head node 

2. Open the `setup_lustre.sh` file and customize the parameters parameters, for example:
   ```bash
   # Configuration parameters
   FS_NAME="testfs"                   # Lustre file system name
   MGS_NODE="mgs01"                   # MGS hostname
   MDTS_PER_MDS=1                     # Number of MDTs per MDS
   OSTS_PER_OSS=8                     # Number of OSTs per OSS

   # Volume sizes (in GB)
   MGT_SIZE=1                         # MGT volume size
   MDT_SIZE=2                         # MDT volume size
   OST_SIZE=128                       # OST volume size
   ```

3. Run the setup script:
   ```bash
   chmod +x setup_lustre.sh
   ./setup_lustre.sh
   ```

   This script:
   - Verifies that the `zfs` and `lustre` modules are loaded (with `lsmod`), or attempts to load them
   - Creates and attaches the EBS volumes (using `ebs_create_attach.sh`) used for MGT, MDT, and OST
     - For both the MGT and MDT, mirrored volumes are used
   - Creates and configures the MGS (Management Server)
   - Sets up MDT (Metadata Target) on MDS nodes
   - Creates OST (Object Storage Target) on OSS nodes
   - Mounts the Lustre file system on **all servers**, but not clients

### Mount on Compute Nodes

Mount the Lustre file system on compute nodes, the file system should already be mounted on the server nodes:
```bash
pdsh -w ^cluster.batch sudo mkdir -p /mnt/lustre
pdsh -w ^cluster.batch sudo mount -t lustre mgs01:/testfs /mnt/lustre
```

## Performance Optimization

### Verify status 

Check with `df`:
```bash
lfs df -h
```
### Stripe Configuration

1. Set default striping across all OSTs for maximum performance:
   ```bash
   sudo lfs setstripe -c -1 /mnt/lustre
   ```

   - Without striping: ~224 MB/s
   - With full striping: ~1.6 GB/s

2. Check current striping:
   ```bash
   lfs getstripe /mnt/lustre
   ```

### With and without striping across all OSTs

* Without setting stripe across all OSTs, the performance is 224 MB/s
* Setting the stripe across all OSTs, the performance is 1.6 GB/s


#### Without using striping across all OSTs:

```sh
[root@storage-mgs-mds-st-storage-mgs-mds-1 lustre]# dd if=/dev/zero of=file.10G bs=1M count=10000
10000+0 records in
10000+0 records out
10485760000 bytes (10 GB, 9.8 GiB) copied, 46.8361 s, 224 MB/s
```

Without setting stripe across all OSTs, the performance is 224 MB/s

Only a few OSTs are used:
```sh
...
testfs-OST0032_UUID        15.7T      108.0M       15.7T   1% /mnt/lustre[OST:50]
testfs-OST0033_UUID        15.7T        8.0M       15.7T   1% /mnt/lustre[OST:51]
testfs-OST0034_UUID        15.7T        8.0M       15.7T   1% /mnt/lustre[OST:52]
testfs-OST0035_UUID        15.7T        8.0M       15.7T   1% /mnt/lustre[OST:53]
testfs-OST0036_UUID        15.7T        8.0M       15.7T   1% /mnt/lustre[OST:54]
testfs-OST0037_UUID        15.7T        8.0M       15.7T   1% /mnt/lustre[OST:55]
testfs-OST0038_UUID        15.7T        8.0M       15.7T   1% /mnt/lustre[OST:56]
testfs-OST0039_UUID        15.7T        8.0M       15.7T   1% /mnt/lustre[OST:57]
testfs-OST003a_UUID        15.7T     1008.0M       15.7T   1% /mnt/lustre[OST:58]
testfs-OST003b_UUID        15.7T        8.0M       15.7T   1% /mnt/lustre[OST:59]
testfs-OST003c_UUID        15.7T        8.0M       15.7T   1% /mnt/lustre[OST:60]
testfs-OST003d_UUID        15.7T        8.0M       15.7T   1% /mnt/lustre[OST:61]
testfs-OST003e_UUID        15.7T        8.0M       15.7T   1% /mnt/lustre[OST:62]
testfs-OST003f_UUID        15.7T        8.0M       15.7T   1% /mnt/lustre[OST:63]

filesystem_summary:      1007.1T       11.3G     1007.1T   1% /mnt/lustre
```


#### Using striping across all OSTs:

Set stripe across all OSTs:
```sh
$ sudo lfs setstripe -c -1 /mnt/lustre
```

Run test
```sh
$ dd if=/dev/zero of=with-stripe.10G bs=1M count=10000
10000+0 records in
10000+0 records out
10485760000 bytes (10 GB, 9.8 GiB) copied, 6.35695 s, 1.6 GB/s
```

Setting the stripe across all OSTs, the performance is 1.6 GB/s

All OSTs are now being used:
```sh
testfs-OST0032_UUID        15.7T      264.0M       15.7T   1% /mnt/lustre[OST:50]
testfs-OST0033_UUID        15.7T      165.0M       15.7T   1% /mnt/lustre[OST:51]
testfs-OST0034_UUID        15.7T      165.0M       15.7T   1% /mnt/lustre[OST:52]
testfs-OST0035_UUID        15.7T      164.0M       15.7T   1% /mnt/lustre[OST:53]
testfs-OST0036_UUID        15.7T      164.0M       15.7T   1% /mnt/lustre[OST:54]
testfs-OST0037_UUID        15.7T      164.0M       15.7T   1% /mnt/lustre[OST:55]
testfs-OST0038_UUID        15.7T      164.0M       15.7T   1% /mnt/lustre[OST:56]
testfs-OST0039_UUID        15.7T      164.0M       15.7T   1% /mnt/lustre[OST:57]
testfs-OST003a_UUID        15.7T        1.1G       15.7T   1% /mnt/lustre[OST:58]
testfs-OST003b_UUID        15.7T      165.0M       15.7T   1% /mnt/lustre[OST:59]
testfs-OST003c_UUID        15.7T      165.0M       15.7T   1% /mnt/lustre[OST:60]
testfs-OST003d_UUID        15.7T      164.0M       15.7T   1% /mnt/lustre[OST:61]
testfs-OST003e_UUID        15.7T      164.0M       15.7T   1% /mnt/lustre[OST:62]
testfs-OST003f_UUID        15.7T      164.0M       15.7T   1% /mnt/lustre[OST:63]

filesystem_summary:      1007.1T       21.1G     1007.0T   1% /mnt/lustre
```

#### Directory striping - ehancing metadata performance




## Troubleshooting

1. Check if Lustre modules are loaded:
   ```bash
   lsmod | egrep "lustre|zfs"
   ```

2. Verify mount status:
   ```bash
   mount | grep lustre
   ```

3. Check Lustre file system status:
   ```bash
   sudo lctl dl
   ```

4. View Lustre logs:
   ```bash
   sudo journalctl -u lustre
   ```
