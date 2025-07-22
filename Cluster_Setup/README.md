# HPC Cluster Setup

## ParallelCluster

### 1. Installation

1. Setup new virtual environment for ParallelCluster:
   ```
   python3.11 -m venv ~/Envs/ParalleCluster-01
   source ~/Envs/ParallelCluster-01/bin/activate
   ```

1. Install ParallelCluster in the virtual environment that was just created (using specific version 3.12 for this example)
   ```
   (ParalleCluster-01)$ pip install aws-parallelcluster==3.12
   ```

1. If needed, fix `setuptools` - versions >69.5.1 will brake ParallelCluster (as of April/2025)
   ```
   pip install setuptools==69.5.1 
   ```

1. Verify ParallelCluster install
   ```
   (ParalleCluster-01)$ pcluster version
   {
     "version": "3.12.0"
   }
   ```

### 2. Verify that the AWS CLI is configured and working

The `aws sts get-caller-identity` command can be used to verify a correctly configured AWS CLI.

This output is for SSO login (using Identity Management) 
```sh
$ aws sts get-caller-identity
{
    "UserId": "AAAAAAAAAAAAAAAAAAAAA:jouser",
    "Account": "111111111111",
    "Arn": "arn:aws:sts::111111111111:assumed-role/AWSnnnnSSO_admin_1111111111111111/jouser"
}
```

This output shows local credentials with the IAM role:
```sh
111122223333    arn:aws:iam::111122223333:user/jouser           XXXXXXXXXXXXXXXXXXXXX 
```

### 3. Create the ParallelCluster VPC and create a example cluster configuration file 

It is recommended to let ParallelCluster create a new VPC (and subnets), which is optionally done as part of the cluster creation process.

Make sure to say yes to the automate VPC creation question: 
```sh
Automate VPC creation? (y/n) [n]: y
```

For the **Allowed values for Network Configuration**, the option "Head node in a public subnet and compute fleet in a 
private subnet" provides more security.

This output shows just the network configuration section:

```sh
(ParalleCluster-01)$ pcluster configure --config cluster-01.yaml
(output removed)
...
Automate VPC creation? (y/n) [n]: y
Allowed values for Availability Zone:
1. us-west-2a
2. us-west-2b
3. us-west-2c
4. us-west-2d
Availability Zone [us-west-2a]:
Allowed values for Network Configuration:
1. Head node in a public subnet and compute fleet in a private subnet
2. Head node and compute fleet in the same public subnet
Network Configuration [Head node in a public subnet and compute fleet in a private subnet]:
Beginning VPC creation. Please do not leave the terminal until the creation is finalized
Creating CloudFormation stack...
Do not leave the terminal until the process has finished.
Stack Name: parallelclusternetworking-pubpriv-11111111111111111 (id: arn:(deleted info))
Status: parallelclusternetworking-pubpriv-1111111111111111 - CREATE_COMPLETE
The stack has been created.
Configuration file written to cluster-01.yaml
```

In the configuration file (`cluster-01.yaml`) the `SubnetId(s)` for both the HeadNode and the `SlurmQueues` can be found and 
reused in other cluster configuration files: 

For the HeadNode:
```yaml
HeadNode:
  Networking:
    SubnetId: subnet-11111111111111111
```

For the Slurm configuration (batch nodes)
```yaml
Scheduling:
  Scheduler: slurm
  SlurmQueues:
  - Name: queue01
    Networking:
      SubnetIds:
        - subnet-22222222222222222
```


### 4. Modify the cluster configuration file for specific workloads

Before creating a cluster, the cluster configuration file that was just created should be modified to fit the workload. Here is an example config file (that uses Slurm not AWS Batch) that can be used as **a reference** for determining which parameters should be used for your workload: https://github.com/aws/aws-parallelcluster/blob/release-3.13/cli/tests/pcluster/example_configs/slurm.full.yaml.

> [!WARNING]
> Verify the version of ParallelCluster - the above link is for v3.13

**<ins> Example config file </ins>**

This config file creates a cluster with 8 storage nodes, and 16 batch nodes, using a placement group.

```sh
Region: us-west-2
Image:
  Os: rhel8
HeadNode:
  InstanceType: m6id.2xlarge
  DisableSimultaneousMultithreading: false
  Ssh:
    KeyName: ec2-key-pdx
  Networking:
    ElasticIp: true   # true|false|EIP-id
    SubnetId: subnet-XXXXXXXXXXXXXXXXX   # VPC: vpc-XXXXXXXXXXXXXXXXX (ParallelClusterVPC-XXXXXXXXXXXXXX)
    AdditionalSecurityGroups:
      - sg-XXXXXXXXXXXXXXXXX             # SG Name: corp-prefix-all-regions
AdditionalPackages:
  IntelSoftware:
    IntelHpcPlatform: false              # true|false Installs Intel Parallel Studio on the head node
Scheduling:
  Scheduler: slurm
  SlurmSettings:
    ScaledownIdletime: 10
    Dns:
      DisableManagedDns: true
  SlurmQueues:
  - Name: storage01
    CapacityType: ONDEMAND
    Networking:
      SubnetIds:
        - subnet-XXXXXXXXXXXXXXXXX   # VPC: vpc-XXXXXXXXXXXXXXXXX (ParallelClusterVPC-XXXXXXXXXXXXXX)
      PlacementGroup:
        Enabled: true
        Name: cluster-01-placement-group-01
    ComputeResources:
    - Name: storage
      InstanceType: m6idn.2xlarge
      MinCount: 8
      MaxCount: 16
      DisableSimultaneousMultithreading: false
  - Name: batch01
    CapacityType: ONDEMAND
    Networking:
      SubnetIds:
        - subnet-XXXXXXXXXXXXXXXXX   # VPC: vpc-XXXXXXXXXXXXXXXXX (ParallelClusterVPC-XXXXXXXXXXXXXX)
      PlacementGroup:
        Enabled: true
        Name: cluster-01-placement-group-01
    ComputeResources:
    - Name: name
      InstanceType: m6idn.xlarge
      MinCount: 16
      MaxCount: 32
      DisableSimultaneousMultithreading: true
```


### 5. Create the cluster

> [!WARNING]
> By default, unless an IP address is specified in the `AllowedIps` field, the security group created for the HeadNode allows ssh 
> traffic from any source (0.0.0.0/0). This inbound rule should be removed or updated to a specific IP address or range.

> [!NOTE]
> It is recommended to use `--rollback-on-failure false` when creating clusters for the 
> first time. It allows for easier troubleshooting.

```bash
# pcluster create-cluster command:
(ParalleCluster-01)$ pcluster create-cluster -n test-cluster01 -c cluster-01.yaml --rollback-on-failure false
```

### 6. Add cluster functionality with additional tools and utilities 

1. **Prepare Required Scripts:**

   **Copy both required scripts to the HeadNode:**
   - [cluster_setup.sh](cluster_setup.sh) - Main cluster setup and validation script
   - [install_pkgs.sh](install_pkgs.sh) - Package installation dependency script

   ```bash
   # Copy both scripts to the head node
   scp cluster_setup.sh install_pkgs.sh ec2-user@<head-node-ip>:~/
   
   # Or if already on the head node, ensure both files are present
   ls -la cluster_setup.sh install_pkgs.sh
   ```

   **Script Dependency:**
   The `cluster_setup.sh` script has a **critical dependency** on `install_pkgs.sh`. This dependency script:
   - Handles robust package installation with RPM lock management
   - Provides retry logic for package installation failures
   - Manages DNF/YUM package manager interactions
   - Validates package installation success across the cluster

   **Execute the main setup script:**
   ```bash
   chmod +x cluster_setup.sh install_pkgs.sh
   ./cluster_setup.sh
   ```

   **Script Overview:**
   The `cluster_setup.sh` script is an AWS ParallelCluster setup and validation tool that prepares clusters for HPC workloads including Lustre parallel filesystems, GPFS, and high-performance computing applications.

   **Key Operations Performed:**
   1. **Package Management**: Installs essential HPC tools and utilities (pdsh, nvme-cli, monitoring tools)
   1. **Cluster Communication**: Sets up pdsh (Parallel Distributed Shell) for parallel command execution
   1. **Host Management**: Creates and distributes cluster host files for node-to-node communication 
   1. **SSH Configuration**: Enables passwordless root access across all cluster nodes
   1. **Environment Setup**: Configures .bash_profile for optimal cluster operations
   1. **Storage Management**: Cleans up Instance Store devices for filesystem use (Lustre/GPFS)
   1. **Monitoring Tools**: Installs performance monitoring and debugging utilities (htop, nmon, iperf3)
   1. **MPI Validation**: Creates, compiles, and tests MPI applications for cluster verification
   1. **Slurm Testing**: Submits test jobs to validate scheduler functionality

   **Integration Points:**
   - Foundation for Lustre filesystem deployments ([../Lustre/setup_lustre.sh](../Lustre/setup_lustre.sh))
   - Supports GPFS installations ([../GPFS/](../GPFS/))
   - Enables benchmarking workflows ([../Benchmarking/](../Benchmarking/))
   - Called by Ansible automation ([../ansible-playbooks/pcluster-lustre/](../ansible-playbooks/pcluster-lustre/))

   **Configuration Options:**
   - `CLEANUP_INSTANCE_STORE`: Enable/disable Instance Store cleanup for filesystem use
   - `PACKAGE_CHECK`: Enable/disable package installation across cluster
   - `REQUIRED_PKGS`: Customize list of packages to install

   **Prerequisites:**
   - Running on AWS ParallelCluster head node
   - Slurm scheduler configured and operational
   - Appropriate sudo permissions
   - `install_pkgs.sh` script in same directory
   - Network connectivity to all cluster nodes

   **Output:**
   - Configured cluster ready for HPC workloads
   - MPI test results in `~/mpi-test.out`
   - Cluster host files for parallel operations
   - Performance monitoring tools installed and configured

2. Verify MPI test was successful:
   ```bash
   $ cat mpi-test.out
   Currently Loaded Modulefiles:
    1) openmpi/4.1.7
   Hello world from processor batch01-st-batch-31, rank 30 out of 32 processors
   Hello world from processor batch01-st-batch-27, rank 26 out of 32 processors
   Hello world from processor batch01-st-batch-28, rank 27 out of 32 processors
   Hello world from processor batch01-st-batch-30, rank 29 out of 32 processors
   Hello world from processor batch01-st-batch-29, rank 28 out of 32 processors
   Hello world from processor batch01-st-batch-32, rank 31 out of 32 processors
   ...
   ```

3. Verify with a pdsh command that the /etc/hosts file is the same across the cluster 
   ```bash
   # This should return a consolidated output for all hosts
   $ pdsh cat /etc/hosts | dshbak -c
   ```
