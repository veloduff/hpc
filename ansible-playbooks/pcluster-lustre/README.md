# Lustre Cluster Automation with ParallelCluster

This directory contains Ansible automation for deploying a cluster with a Lustre parallel filesystem, built with AWS ParallelCluster. The automation provides a complete HPC environment with high-performance storage.

**Important**: This is a **step-by-step Lustre deployment process** that builds each Lustre component individually (MGS, MDS, OSS) and creates the filesystem from scratch. This approach **does not use AWS built-in services** like Amazon FSx for Lustre, but instead deploys a native Lustre filesystem directly on EC2 instances with full control over configuration, performance tuning, and customization.

## Architecture

### Cluster Components
- **Head Node**: Cluster management and job submission
- **MGS (Management Server)**: Lustre management
- **MDS (Metadata Server)**: Lustre metadata storage 
- **OSS (Object Storage Server)**: Lustre data storage 
- **Compute Nodes**: Batch processing with Lustre client access

### Storage Architecture
- **ZFS Backend**: High-performance, enterprise-grade storage
- **Optionally use NVMe Instance Store**: Ultra-low latency local storage

## Current working versions:

| Lustre | RHEL | Kernel |
|--------|------|--------|
| lustre-2.15.4 | 8.10 | 4.18.0-553.54.1.el8_10 |
| lustre-2.15.7 | 8.10 | 4.18.0-553.63.1.el8_10 |

## Prerequisites

* It is strongly recommended that you run this (and ParallelCluster) in a Python virtual environment.
* You will need to be familiar with AWS ParallelCluster

### Required Tools
- **Ansible**: `pip install ansible`
- **AWS ParallelCluster CLI**: `pip install aws-parallelcluster`
- **AWS CLI**: Configured with appropriate credentials
- **jq**: JSON processor for configuration parsing
  - macOS: `brew install jq`
  - Ubuntu: `apt-get install jq`
  - RHEL/CentOS: `yum install jq`

### AWS Requirements
- **AWS Account** with appropriate permissions
- **VPC and Subnets** Use `pcluster configure` to automate the setup for HPC workloads
- **EC2 Key Pair** for SSH access
- **Placement Group** (optional, for enhanced networking)
- **Custom AMI** (optional, for pre-configured environments)

### Permissions Required
- EC2 instance management, Lustre server instances will need EC2 full access
- VPC and networking configuration
- IAM role creation and management
- CloudFormation stack operations
- S3 bucket access (for ParallelCluster)

## Quick Start

### 1. Basic Deployment

```bash
cd ansible-playbooks/pcluster-lustre/
./run-pcluster-lustre.sh
```

### 2. Example Interactive Session

```bash
(ParallelCluster-01) [duff@system01 pcluster-lustre]$ ./run-pcluster-lustre.sh
ParallelCluster Lustre Cluster Ansible Setup
============================================
Verifying AWS credentials... verified
Cluster name []: cluster-01
AWS region []: us-west-2
Custom AMI []: ami-00001111222233333
Operating System []: rhel8
SSH key file path []: /path/to/my-key.pem
EC2 key pair name [my-key.pem]:
Head node subnet ID []: subnet-11112222333344455  
Compute subnet ID []: subnet-aaaa11112222aaaa
Placement group name []: my-pg-01
File system size (small/medium/large/xlarge/local) [small]:

Using wrapper script: ./pcluster-lustre-post-install-wrapper.sh
Post-install wrapper script will run the following scripts:
  1. ../../Cluster_Setup/cluster_setup.sh
  2. ../../Lustre/fix_lustre_hosts_files.sh
  3. ../../Lustre/setup_lustre.sh

Note: The following scripts are required dependencies and will be
      copied to the head node as part of the setup process:
      - ../../Cluster_Setup/install_pkgs.sh (required by cluster_setup.sh)
      - ../../Storage_Management/ebs_create_attach.sh (required by setup_lustre.sh)
      - ./create_lustre_components.sh (required by setup_lustre.sh)
      - ./lustre_fs_settings.sh (required by create_lustre_components.sh)

Cluster configuration set to: small

<removed deployment output>

PLAY RECAP **************************************************************************************************************************
localhost                  : ok=14   changed=8    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0

Playbook run took 0 days, 0 hours, 19 minutes, 32 seconds
Thursday 24 July 2025  07:37:43 -0700 (0:00:00.013)       0:19:32.650 *********

Setup complete! Check ansible-generated-pcluster-lustre-access.txt for connection details.
```

### 3. Accessing the Cluster

```bash
ssh -i /path/to/my-key.pem ec2-user@<ip_address>
```

## Post-Deployment Verification

### 1. Check Slurm Status

```bash
[ec2-user@ip-10-0-0-0 ~]$ sinfo
PARTITION    AVAIL  TIMELIMIT  NODES  STATE NODELIST
storage-mgs*    up   infinite      1   idle storage-mgs-st-storage-mgs-1
storage-mds     up   infinite      6  idle~ storage-mds-dy-storage-mds-[1-6]
storage-mds     up   infinite      2   idle storage-mds-st-storage-mds-[1-2]
storage-oss     up   infinite     14  idle~ storage-oss-dy-storage-oss-[1-14]
storage-oss     up   infinite      2   idle storage-oss-st-storage-oss-[1-2]
batch01         up   infinite     30  idle~ batch01-dy-batch-[1-30]
batch01         up   infinite      2   idle batch01-st-batch-[1-2]
```

### 2. Verify Lustre Filesystem

```bash
[ec2-user@ip-10-0-0-0 ~]$ ssh mgs01 lfs df -h
UUID                       bytes        Used   Available Use% Mounted on
projects-MDT0000_UUID      488.4G        7.5M      488.4G   1% /projects[MDT:0]
projects-MDT0001_UUID      488.4G        7.2M      488.4G   1% /projects[MDT:1]
projects-OST0000_UUID        1.1T        9.0M        1.1T   1% /projects[OST:0]
projects-OST0001_UUID        1.1T        9.0M        1.1T   1% /projects[OST:1]

filesystem_summary:         2.2T       18.0M        2.2T   1% /projects
```

### 3. Test Lustre Performance

```bash
# Basic I/O test
dd if=/dev/zero of=/projects/test_file bs=1M count=1000

# Check striping
lfs getstripe /projects/test_file

# Set custom striping for large files
lfs setstripe -c 4 /projects/large_files/
```

## Cleanup - delete the cluster and file system components
```sh
pcluster delete-cluster -n <cluster-name>
```

## Cluster Size Configurations

### Small (Development/Testing)
- **Head Node**: m6idn.xlarge
- **MGS**: 1x m6idn.large
- **MDS**: 2-8x m6idn.xlarge
- **OSS**: 4-16x m6idn.xlarge
- **Compute**: 4-32x m6idn.large
- **Capacity**: ~2-8TB
- **IOPS min**: 20K

### Medium (Small Production)
- **Head Node**: m6idn.xlarge
- **MGS**: 1x m6idn.xlarge
- **MDS**: 4-8x m6idn.xlarge
- **OSS**: 20-40x m6idn.xlarge
- **Compute**: 8-128x m6idn.large
- **Capacity**: ~20-40TB
- **IOPS min**: 40K

### Large (Production)
- **Head Node**: m6idn.2xlarge
- **MGS**: 1x m6idn.xlarge
- **MDS**: 8-16x m6idn.2xlarge
- **OSS**: 40-128x m6idn.2xlarge
- **Compute**: 16-256x m6idn.xlarge
- **Capacity**: ~40-128TB
- **IOPS min**: 80K

### XLarge (High-Performance)
- **Head Node**: m6idn.2xlarge
- **MGS**: 1x m6idn.xlarge
- **MDS**: 16x m6idn.2xlarge (fixed)
- **OSS**: 40-128x m6idn.2xlarge
- **Compute**: 16-256x m6idn.xlarge
- **Capacity**: ~40-128TB
- **IOPS min**: 160K

### Local (Maximum Performance)
- **Head Node**: m6idn.2xlarge
- **MGS**: 1x m6idn.xlarge
- **MDS**: 16-32x m6idn.2xlarge
- **OSS**: 40-64x m6idn.2xlarge
- **Compute**: 16-256x m6idn.xlarge
- **Capacity**: determined by the size of the Instance Store vol
- **IOPS min**: determined by the Instance Store vol


## Project Structure

### Core Scripts
- **[`run-pcluster-lustre.sh`](run-pcluster-lustre.sh)**: Main deployment script
- **[`pcluster-lustre-playbook.yml`](pcluster-lustre-playbook.yml)**: Ansible orchestration playbook
- **[`pcluster-lustre-template.yaml`](pcluster-lustre-template.yaml)**: ParallelCluster configuration template
- **[`pcluster-lustre-post-install-wrapper.sh`](pcluster-lustre-post-install-wrapper.sh)**: Post-deployment automation

### Configuration Files
- **[`pcluster-lustre-inventory.ini`](pcluster-lustre-inventory.ini)**: Ansible inventory
- **[`lustre_fs_settings.sh`](lustre_fs_settings.sh)**: Lustre filesystem configuration
- **[`create_lustre_components.sh`](create_lustre_components.sh)**: Lustre component creation
- **[`ansible.cfg`](ansible.cfg)**: Ansible configuration

### Dependencies
- **`../../Cluster_Setup/cluster_setup.sh`**: Basic cluster initialization
- **`../../Cluster_Setup/install_pkgs.sh`**: Package management
- **`../../Lustre/fix_lustre_hosts_files.sh`**: Network configuration
- **`../../Lustre/setup_lustre.sh`**: Lustre installation and setup
- **`../../Storage_Management/ebs_create_attach.sh`**: Storage management

## Configuration Options

### Environment Variables
```bash
# Optional: Set default values to skip interactive prompts
export CLUSTER_NAME="my-lustre-cluster"
export AWS_REGION="us-west-2"
export KEY_PATH="/path/to/my-key.pem"
export HEADNODE_SUBNET_ID="subnet-12345"
export COMPUTE_SUBNET_ID="subnet-67890"
```

### Custom AMI Requirements
If using a custom AMI, ensure it includes:
- **RHEL 8.x** or compatible OS
- **DKMS** installed and working
- **ZFS kernel modules built and installed (check with dkms)** 
- **Lustre server modules built and installed (check with dkms)**

## Performance Optimization

### Common Stripe Count Values:

- `-c 0`: Use filesystem default (typically 1-2 OSTs)
- `-c 1`: Single OST (no striping)
- `-c 2`: Stripe across 2 OSTs
- `-c 4`: Stripe across 4 OSTs
- `-c -1`: Stripe across ALL available OSTs (maximum parallelism)

### Lustre Tuning
```bash
# Set optimal striping for large files
lfs setstripe -c -1 /projects/large_files/

# Set optimal striping for small files and metadata
lfs setstripe -c 0 /projects/large_files/

# Monitor performance
lfs df -h
lctl get_param osc.*.stats
```
### Data Processing
```bash
# Set up high-performance directory
mkdir /projects/data_processing
lfs setstripe -c 8 /projects/data_processing

# Process large datasets
sbatch --array=1-100 process_data.sh
```

### Machine Learning
```bash
# Create ML workspace with optimal striping
mkdir /projects/ml_training
lfs setstripe -c 16 /projects/ml_training

# Submit distributed training job
sbatch --nodes=8 --gres=gpu:8 train_model.py
```
