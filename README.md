# HPC Infrastructure Automation 

## Repository Overview

This is a comprehensive High Performance Computing (HPC) infrastructure automation repository designed for AWS cloud deployments. It provides production-ready solutions for parallel computing workloads, advanced parallel filesystems, remote visualization, and performance benchmarking. The repository combines AWS ParallelCluster with enterprise-grade parallel filesystems and automated deployment tools to deliver scalable, high-performance computing environments.

## Key Capabilities

- **Automated HPC Cluster Deployment** with AWS ParallelCluster
- **Advanced Parallel Filesystems** (Lustre, GPFS/Spectrum Scale)
- **Remote Visualization** with NICE DCV for graphics-intensive workloads
- **Performance Benchmarking** with industry-standard tools (IOR, SPECsfs)
- **Storage Management** with intelligent EBS volume provisioning
- **Infrastructure as Code** with Ansible automation and templates

## Core Architecture Components

### 1. **Infrastructure Automation Layer**
- **Ansible-based orchestration** for consistent, repeatable deployments
- **Interactive deployment scripts** with parameter validation
- **Template-driven configuration management** for different cluster sizes
- **Infrastructure-as-code practices** with version control

### 2. **Parallel Filesystem Support**
- **Lustre Filesystem**: Primary focus with ZFS backend, automated MGS/MDS/OSS deployment
- **IBM Spectrum Scale (GPFS)**: Enterprise-grade parallel filesystem support
- **Performance optimization** with striping patterns and storage allocation strategies

### 3. **Storage Management System**
- **EBS volume automation** with configurable IOPS/throughput (io1, io2, gp3)
- **Instance Store management** with LVM cleanup and optimization
- **Mirrored volumes** for high availability (MGT components)
- **Automated device detection** and attachment

### 4. **Cluster Management Tools**
- **pdsh/dshbak integration** for parallel command execution
- **SSH key distribution** and passwordless access setup
- **Host file management** with short hostname creation
- **Package management** with robust RPM lock handling

## Repository Structure and Key Files

### Cluster Setup ([`Cluster_Setup/`](Cluster_Setup/))
- **[`cluster_setup.sh`](Cluster_Setup/cluster_setup.sh)**: Comprehensive cluster initialization and MPI testing
- **[`install_pkgs.sh`](Cluster_Setup/install_pkgs.sh)**: Robust package management with lock handling
- **[`base-cluster.yaml`](Cluster_Setup/base-cluster.yaml)**: Example ParallelCluster configuration
- **[`README.md`](Cluster_Setup/README.md)**: ParallelCluster installation and setup guide

### Storage Management ([`Storage_Management/`](Storage_Management/))
- **[`ebs_create_attach.sh`](Storage_Management/ebs_create_attach.sh)**: Automated EBS volume provisioning and attachment
- **[`disk_management.md`](Storage_Management/disk_management.md)**: Comprehensive disk and LVM management guide

### Lustre Components ([`Lustre/`](Lustre/))
- **[`setup_lustre.sh`](Lustre/setup_lustre.sh)**: Master Lustre deployment orchestrator
- **[`fix_lustre_hosts_files.sh`](Lustre/fix_lustre_hosts_files.sh)**: Network and hostname management
- **[`README.md`](Lustre/README.md)**: Complete Lustre setup and configuration guide
- **[`lustre.md`](Lustre/lustre.md)**: Lustre filesystem documentation
- **[`customize_pc_ami_lustre.md`](Lustre/customize_pc_ami_lustre.md)**: ParallelCluster AMI customization guide

### Ansible Automation ([`ansible-playbooks/pcluster-lustre/`](ansible-playbooks/pcluster-lustre/))
- **[`run-pcluster-lustre.sh`](ansible-playbooks/pcluster-lustre/run-pcluster-lustre.sh)**: Interactive cluster deployment with size presets
- **[`pcluster-lustre-playbook.yml`](ansible-playbooks/pcluster-lustre/pcluster-lustre-playbook.yml)**: Main orchestration playbook
- **[`pcluster-lustre-post-install-wrapper.sh`](ansible-playbooks/pcluster-lustre/pcluster-lustre-post-install-wrapper.sh)**: Post-deployment automation chain
- **[`create_lustre_components.sh`](ansible-playbooks/pcluster-lustre/create_lustre_components.sh)**: Individual Lustre component creation
- **[`lustre_fs_settings.sh`](ansible-playbooks/pcluster-lustre/lustre_fs_settings.sh)**: Lustre filesystem configuration settings
- **[`pcluster-lustre-template.yaml`](ansible-playbooks/pcluster-lustre/pcluster-lustre-template.yaml)**: Ansible template for cluster configuration

### Benchmarking Suite ([`Benchmarking/`](Benchmarking/))
- **[`README.md`](Benchmarking/README.md)**: Comprehensive HPC benchmarking guide with IOR and SPECsfs documentation
- **[`run_ior_benchmark.sh`](Benchmarking/run_ior_benchmark.sh)**: Automated IOR benchmark execution
- **[`setup_specsfs.sh`](Benchmarking/setup_specsfs.sh)**: SPECsfs benchmark setup automation
- **[`vdbench.md`](Benchmarking/vdbench.md)**: VDBench performance testing guide

### Remote Visualization ([`DCV/`](DCV/))
- **[`launch_dcv_instance.sh`](DCV/launch_dcv_instance.sh)**: Automated NICE DCV server deployment for remote desktop access

### GPFS Support ([`GPFS/`](GPFS/))
- **[`README.md`](GPFS/README.md)**: IBM Spectrum Scale installation and configuration guide

### Scheduler Documentation ([`Schedulers/`](Schedulers/))
- **[`README.md`](Schedulers/README.md)**: Scheduler documentation and configuration guides

### Additional Ansible Playbooks
- **[`ansible-playbooks/instance-launch/`](ansible-playbooks/instance-launch/)**: Basic EC2 instance deployment
- **[`ansible-playbooks/pcluster-basic-setup/`](ansible-playbooks/pcluster-basic-setup/)**: Basic ParallelCluster setup
- **[`ansible-playbooks/pcluster-advanced-setup/`](ansible-playbooks/pcluster-advanced-setup/)**: Advanced ParallelCluster configurations


### Getting started 

1. **Prerequisites**: Ensure AWS CLI and ParallelCluster are configured
2. **Choose your path**: 
   - Basic cluster: Start with [`Cluster_Setup/README.md`](Cluster_Setup/README.md)
   - Lustre filesystem: Use [`ansible-playbooks/pcluster-lustre/run-pcluster-lustre.sh`](ansible-playbooks/pcluster-lustre/run-pcluster-lustre.sh)
   - GPFS filesystem: Follow [`GPFS/README.md`](GPFS/README.md)
3. **Benchmark**: Use tools in [`Benchmarking/`](Benchmarking/) to validate performance
