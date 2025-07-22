## Customize ParallelCluster AMI with Lustre server

Example AMI: ami-068c41ec88596d8b4 (aws-parallelcluster-3.12.0-rhel8-hvm-x86_64-202412170018 2024-12-17T00-22-24.374Z)

```sh

# Remove existing Lustre packages as these will conflict and prevent 
#  install of Lustre server (version mismatch) 
dnf remove lustre-client kmod-lustre-client

# Verify that SELinux is disabled
$ sestatus
SELinux status:                 disabled

# Reboot to clean out kernel modules completely
reboot

# Update and reboot
dnf update

# reboot
reboot

# Install ZFS
dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
dnf install -y https://zfsonlinux.org/epel/zfs-release-2-3$(rpm --eval "%{dist}").noarch.rpm
dnf install -y kernel-devel zfs

# Verify ZFS is working
dkms status
modprobe -v zfs
zpool version

# Install Lustre, setup repo

$ cat /etc/yum.repos.d/lustre.repo
[lustre-server]
name=lustre-server
baseurl=https://downloads.whamcloud.com/public/lustre/lustre-2.15.4/el8.9/server/
exclude=*debuginfo*
enabled=0
gpgcheck=0

# Enable CodeReady repo
dnf config-manager --set-enabled codeready-builder-for-rhel-8-rhui-rpms

# Install Lustre server
dnf --enablerepo=lustre-server install lustre-dkms lustre-osd-zfs-mount lustre

# Verify Lustre install
modprobe -v lustre 

$ lctl
lctl > ping 172.31.26.176
12345-0@lo
12345-172.31.26.176@tcp
lctl > list_nids
172.31.26.176@tcp
```


