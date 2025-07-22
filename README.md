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

## Key Technical Features

### Advanced Lustre Implementation
- **Multi-component architecture**: MGS (Management), MDS (Metadata), OSS (Object Storage)
- **Scalable design**: Supports hundreds of nodes with configurable component counts
- **ZFS backend**: Provides data integrity and advanced storage features
- **Performance tuning**: Directory striping, I/O optimization for EDA workloads

### Robust Automation
- **Error recovery mechanisms**: Comprehensive validation and retry logic
- **Parallel execution**: Efficient cluster-wide operations
- **Modular design**: Independent component lifecycle management
- **Comprehensive logging**: Detailed debugging and monitoring capabilities

### Performance Benchmarking
- **IOR integration**: Parallel I/O performance testing
- **SPECsfs 2014 SP2**: Industry-standard filesystem benchmarking
- **EDA workload optimization**: Specialized configurations for electronic design workflows
- **Performance monitoring**: Integration with nmon, htop, and custom tools

## Repository Structure and Key Files

### Cluster Setup ([`Cluster_Setup/`](Cluster_Setup/))
- **[`cluster_setup.sh`](Cluster_Setup/cluster_setup.sh)**: Comprehensive cluster initialization and MPI testing
- **[`install_pkgs.sh`](Cluster_Setup/install_pkgs.sh)**: Robust package management with lock handling
- **[`cluster-config.yaml`](Cluster_Setup/cluster-config.yaml)**: Example ParallelCluster configuration
- **[`README.md`](Cluster_Setup/README.md)**: ParallelCluster installation and setup guide

### Storage Management ([`Storage_Management/`](Storage_Management/))
- **[`ebs_create_attach.sh`](Storage_Management/ebs_create_attach.sh)**: Automated EBS volume provisioning and attachment
- **[`disk_management.md`](Storage_Management/disk_management.md)**: Comprehensive disk and LVM management guide

### Lustre Components ([`Lustre/`](Lustre/))
- **[`setup_lustre.sh`](Lustre/setup_lustre.sh)**: Master Lustre deployment orchestrator
- **[`fix_lustre_hosts_files.sh`](Lustre/fix_lustre_hosts_files.sh)**: Network and hostname management
- **[`disk_management.sh`](Lustre/disk_management.sh)**: Lustre-specific disk management utilities
- **[`pcluster_lustre.yaml`](Lustre/pcluster_lustre.yaml)**: ParallelCluster configuration template for Lustre
- **[`README.md`](Lustre/README.md)**: Complete Lustre setup and configuration guide
- **[`lustre.md`](Lustre/lustre.md)**: Lustre filesystem documentation

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
- **Ubuntu Desktop environment** with full graphics acceleration
- **Web-based access** via HTTPS for secure remote visualization
- **Automated session management** and user provisioning

### GPFS Support ([`GPFS/`](GPFS/))
- **[`gpfs_spectrum_storage.md`](GPFS/gpfs_spectrum_storage.md)**: IBM Spectrum Scale installation and configuration
- **[`gpfs_install.sh`](GPFS/gpfs_install.sh)**: Automated GPFS installation script

### Scheduler Documentation ([`Schedulers/`](Schedulers/))
- **[`slurm.md`](Schedulers/slurm.md)**: Slurm workload manager configuration and usage

### Additional Ansible Playbooks
- **[`ansible-playbooks/instance-launch/`](ansible-playbooks/instance-launch/)**: Basic EC2 instance deployment
- **[`ansible-playbooks/pcluster-basic-setup/`](ansible-playbooks/pcluster-basic-setup/)**: Basic ParallelCluster setup
- **[`ansible-playbooks/pcluster-advanced-setup/`](ansible-playbooks/pcluster-advanced-setup/)**: Advanced ParallelCluster configurations
- **[`ansible-playbooks/pcluster-generic/`](ansible-playbooks/pcluster-generic/)**: Generic ParallelCluster templates

### Additional Resources
- **[`presentations/`](presentations/)**: Technical presentations and documentation
- **[`_assets/`](_assets/)**: ISO files and installation media for benchmarking tools

## Quick Start Guide

### 1. Basic Cluster Setup
Start with the comprehensive cluster setup guide:
```bash
# Follow the ParallelCluster installation guide
cat Cluster_Setup/README.md

# Deploy a basic cluster
cd Cluster_Setup/
./cluster_setup.sh
```

### 2. Lustre Filesystem Deployment
For high-performance parallel filesystem:
```bash
# Review Lustre setup documentation
cat Lustre/README.md

# Deploy using Ansible automation
cd ansible-playbooks/pcluster-lustre/
./run-pcluster-lustre.sh
```

### 3. Performance Benchmarking
Test your deployment:
```bash
# Review benchmarking options
cat Benchmarking/README.md

# Run IOR benchmarks
cd Benchmarking/
./run_ior_benchmark.sh
```

### 4. Remote Visualization Setup
Deploy NICE DCV for graphics-intensive workloads:
```bash
# Review DCV documentation and deploy
cd DCV/
./launch_dcv_instance.sh
```

## Deployment Capabilities

### Cluster Size Configurations
- **Small**: 8 storage + 16 batch nodes (development/testing)
- **Medium**: 20 storage + 128 batch nodes (production workloads)
- **Large**: 40 storage + 256 batch nodes (enterprise scale)
- **XLarge**: 40+ storage + 256+ batch nodes (maximum performance)
- **Local**: Instance store optimization for ephemeral high-performance storage

### Storage Options
- **EBS-based**: Persistent, configurable performance (io1, io2, gp3)
- **Instance Store**: High-performance ephemeral storage with automated cleanup
- **Hybrid configurations**: Optimized for different workload requirements

### Network Optimization
- **Placement groups**: Low-latency networking for HPC workloads
- **Multi-AZ support**: High availability and fault tolerance
- **Custom AMI support**: Pre-configured images with ZFS and Lustre

## Performance Achievements

### Benchmarking Results
- **Lustre Performance**: Up to 2.4+ TB/s aggregate throughput in large configurations
- **EDA Workload Support**: 300+ business metric operations with sub-5ms latency
- **Scalability**: Successfully tested with 40+ OSS nodes and 80+ OSTs
- **I/O Optimization**: 7x performance improvement with proper striping (224 MB/s → 1.6 GB/s)

### Production Readiness
- **Automated deployment**: End-to-end cluster creation in minutes
- **Comprehensive validation**: MPI testing, filesystem verification, performance benchmarking
- **Enterprise features**: High availability, monitoring, debugging tools
- **Documentation**: Extensive guides, troubleshooting, and best practices

## Use Cases and Applications

### Primary Applications
- **EDA Workloads**: Electronic design automation with high metadata operations
- **HPC Computing**: Parallel computing with MPI applications
- **Data Analytics**: Large-scale data processing and analysis
- **Scientific Computing**: Research workloads requiring high-performance I/O

### Deployment Scenarios
- **Development environments**: Small-scale testing and development
- **Production workloads**: Enterprise-scale parallel computing
- **Burst computing**: On-demand high-performance computing resources
- **Hybrid cloud**: Integration with existing on-premises infrastructure

## Getting Started

1. **Prerequisites**: Ensure AWS CLI and ParallelCluster are configured
2. **Choose your path**: 
   - Basic cluster: Start with [`Cluster_Setup/README.md`](Cluster_Setup/README.md)
   - Lustre filesystem: Use [`ansible-playbooks/pcluster-lustre/run-pcluster-lustre.sh`](ansible-playbooks/pcluster-lustre/run-pcluster-lustre.sh)
   - GPFS filesystem: Follow [`GPFS/gpfs_spectrum_storage.md`](GPFS/gpfs_spectrum_storage.md)
3. **Benchmark**: Use tools in [`Benchmarking/`](Benchmarking/) to validate performance
4. **Monitor**: Leverage built-in monitoring and debugging capabilities

This repository represents a sophisticated, production-ready HPC infrastructure solution that combines AWS cloud services with advanced parallel filesystems, providing automated deployment, comprehensive monitoring, and optimized performance for demanding computational workloads.
