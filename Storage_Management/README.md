# Disk management

Prior to creating a file system, the disks will need to be available as just 
devices, without a file system or partition. There are multiple ways to accomplish
this.

## LVM vs Partitioning

EC2 instances will use both LVM and Partitioning on the same instance. For the root 
file system below using EBS, it is using partitioning. For the **Instance Store** it
is using LVM. Here is more information: https://www.redhat.com/en/blog/lvm-vs-partitioning

Using `lsblk`, the type of device is seen:
```sh
$ lsblk
NAME                 MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
nvme0n1              259:0    0    45G  0 disk             <--------- Disk device
├─nvme0n1p1          259:2    0     1M  0 part             <--------- Partition
├─nvme0n1p2          259:3    0   200M  0 part /boot/efi   <--------- Partition
└─nvme0n1p3          259:4    0  44.8G  0 part /           <--------- Partition
nvme1n1              259:1    0 220.7G  0 disk             <--------- Disk device
└─vg.01-lv_ephemeral 253:0    0 220.7G  0 lvm  /scratch    <--------- Logical Volume 
```

When managing disk devices the method used will vary depending on how the disk was setup. In other
words, `parted` and `lv*` commands can not be used interchangeably.

For example, when running `parted` on both device types. On the device using partitions, it returns the 
partition information.

```sh
$ sudo parted /dev/nvme0n1 print
Model: NVMe Device (nvme)
Disk /dev/nvme0n1: 48.3GB
Sector size (logical/physical): 512B/4096B
Partition Table: gpt
Disk Flags:

Number  Start   End     Size    File system  Name  Flags
 1      1049kB  2097kB  1049kB                     bios_grub
 2      2097kB  212MB   210MB   fat16              boot, esp
 3      212MB   48.3GB  48.1GB  xfs
```

On the device using LVM, it returns and `unrecognised disk label` error:
```sh
$ sudo parted /dev/nvme1n1 print
Error: /dev/nvme1n1: unrecognised disk label
Model: NVMe Device (nvme)
Disk /dev/nvme1n1: 237GB
Sector size (logical/physical): 512B/512B
Partition Table: unknown
Disk Flags:
```

Running `lvscan` only returns information about the one logical volume:
```sh
$ sudo lvscan
  ACTIVE            '/dev/vg.01/lv_ephemeral' [<220.72 GiB] inherit
```


## Delete existing Logical Volume from Instance Store 

Prior to deleting a logical volume, confirmation of which logical volume to 
delete will need to be done. This section documents a process of cross-referencing
commands to ensure the correct logical volume is deleted.

> [!WARNING]
> Instance Store volumes are locally attached NVMe drives. If Instance Store 
> volumes will be used for a file system, the existing file system (e.g., `/scratch`) 
> will need to be unmounted, and the logical volume removed.

The `nvme` CLI command will need to be installed, shown here installing across the cluster:
```sh
$ pdsh sudo yum -y install nvme-cli
```

Get the names and locations of the locally attached NVMe drives (aka Instance Store):
```sh
$ sudo nvme list
Node                  SN                   Model                                    Namespace Usage                      Format           FW Rev
--------------------- -------------------- ---------------------------------------- --------- -------------------------- ---------------- --------
/dev/nvme0n1          vol00000000000000000 Amazon Elastic Block Store               1          48.32  GB /  48.32  GB    512   B +  0 B   2.0
/dev/nvme1n1          AWS11111111111111111 Amazon EC2 NVMe Instance Storage         1         237.00  GB / 237.00  GB    512   B +  0 B   0
```

The Instance Store device is `/dev/nvme1n1`.

Similar information can also be found with `lsscsi`:
```sh
$ sudo lsscsi
[N:0:0:1]    disk    Amazon Elastic Block Store__1              /dev/nvme0n1
[N:1:5:1]    disk    Amazon EC2 NVMe Instance Storage__1        /dev/nvme1n1
```

The `lsblk -f` command is used to find the mount point and UUID of the both the partitions and logical volumes:
```sh
$ lsblk -f
NAME                 FSTYPE      LABEL UUID                                   MOUNTPOINT
nvme0n1
├─nvme0n1p1
├─nvme0n1p2          vfat              AAAA-AAAA                              /boot/efi
└─nvme0n1p3          xfs         root  AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA   /
└─nvme0n1p3          xfs         root  BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB   /
nvme1n1              LVM2_member       CCCCCC-CCCC-CCCC-CCCC-CCCC-CCCC-CCCCCC 
└─vg.01-lv_ephemeral ext4              DDDDDD-DDDD-DDDD-DDDD-DDDD-DDDD-DDDDDD /scratch
```

At this point, it is confirmed that the `vg.01-lv_ephemeral` logical volume is mounted on `/scratch`.

The `blkid` command can used to further logical volume by checking the UUID: 
```sh
$ sudo blkid
/dev/nvme0n1p2: SEC_TYPE="msdos" UUID="7B77-95E7" BLOCK_SIZE="512" TYPE="vfat" PARTUUID="AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"
/dev/nvme0n1p3: LABEL="root" UUID="BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB" BLOCK_SIZE="512" TYPE="xfs" PARTUUID="CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC"
/dev/nvme1n1: UUID="DDDDDD-DDDD-DDDD-DDDD-DDDD-DDDD-DDDDDD" TYPE="LVM2_member"
/dev/mapper/vg.01-lv_ephemeral: UUID="EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE" BLOCK_SIZE="4096" TYPE="ext4"
/dev/nvme0n1: PTUUID="GGGGGGGG-GGGG-GGGG-GGGG-GGGGGGGGGGGG" PTTYPE="gpt"
/dev/nvme0n1p1: PARTUUID="HHHHHHHH-HHHH-HHHH-HHHH-HHHHHHHHHHHH"
```

The `findmnt` command will also show file system and mount point information. The command below shows 
the `ext4,ext3,xfs` file systems that are mounted. The `findmnt` command can also be run without 
arguments to see all mounted file system types (e.g., sysfs, cgroup, tpmfs, etc.):

```sh
$ sudo findmnt -lt ext4,ext3,xfs
TARGET   SOURCE                         FSTYPE OPTIONS
/        /dev/nvme0n1p3                 xfs    rw,relatime,attr2,inode64,logbufs=8,logbsize=32k,noquota
/scratch /dev/mapper/vg.01-lv_ephemeral ext4   rw,noatime,nodiratime
```

The `df -Th` command will show similar information:
```sh
$ df -Th
Filesystem                     Type      Size  Used Avail Use% Mounted on
devtmpfs                       devtmpfs  7.5G     0  7.5G   0% /dev
tmpfs                          tmpfs     7.6G     0  7.6G   0% /dev/shm
tmpfs                          tmpfs     7.6G  217M  7.4G   3% /run
tmpfs                          tmpfs     7.6G     0  7.6G   0% /sys/fs/cgroup
/dev/nvme0n1p3                 xfs        45G   31G   15G  68% /
/dev/nvme0n1p2                 vfat      200M  5.8M  194M   3% /boot/efi
/dev/mapper/vg.01-lv_ephemeral ext4      217G   28K  206G   1% /scratch
tmpfs                          tmpfs     1.6G  4.0K  1.6G   1% /run/user/1000
```

Commands specific to managing logical volumes can be also be used. The `pvdisplay -m` command will show the physical to 
logical mapping of the devices:
```sh
$ sudo pvdisplay -m
  --- Physical volume ---
  PV Name               /dev/nvme1n1
  VG Name               vg.01
  PV Size               220.72 GiB / not usable 4.81 MiB
  Allocatable           yes (but full)
  PE Size               4.00 MiB
  Total PE              56504
  Free PE               0
  Allocated PE          56504
  PV UUID               AAAAAA-AAAA-AAAA-AAAA-AAAA-AAAA-AAAAAA 

  --- Physical Segments ---
  Physical extent 0 to 56503:
    Logical volume	/dev/vg.01/lv_ephemeral
    Logical extents	0 to 56503
```

The `lvdisplay -m` command shows most of the above information all in one place. It will 
show the logical to physical mapping, and will show the physical volume location for 
the LV:

```sh
$ sudo lvdisplay -m
  --- Logical volume ---
  LV Path                /dev/vg.01/lv_ephemeral
  LV Name                lv_ephemeral
  VG Name                vg.01
  LV UUID                AAAAAA-AAAA-AAAA-AAAA-AAAA-AAAA-AAAAAA
  LV Write Access        read/write
  LV Creation host, time ip-11-22-33-44, 2025-04-14 22:40:44 +0000
  LV Status              available
  # open                 1
  LV Size                <220.72 GiB
  Current LE             56504
  Segments               1
  Allocation             inherit
  Read ahead sectors     auto
  - currently set to     8192
  Block device           253:0

  --- Segments ---
  Logical extents 0 to 56503:
    Type		linear
    Physical volume	/dev/nvme1n1
    Physical extents	0 to 56503
```

Given the above information, we have (exhaustively) confirmed that the logical 
volume we need to delete is  `/dev/vg.01/lv_ephemeral`.

Before removing the LV, run a before `lsblk` command across the cluster:
```sh
$ pdsh "lsblk -o NAME,TYPE,MOUNTPOINT | sort" | dshbak -c
----------------
queue1-st-compute-[1-4]
----------------
NAME                 TYPE MOUNTPOINT
nvme0n1              disk
├─nvme0n1p1          part
├─nvme0n1p2          part /boot/efi
└─nvme0n1p3          part /
nvme1n1              disk
└─vg.01-lv_ephemeral lvm  /scratch
```

Unmount the file system:
```sh
$ pdsh sudo umount -f /scratch
```

Remove the logical volume
```sh
$ pdsh "sudo lvremove /dev/vg.01/lv_ephemeral -f"
queue1-st-compute-1:   Logical volume "lv_ephemeral" successfully removed.
queue1-st-compute-2:   Logical volume "lv_ephemeral" successfully removed.
queue1-st-compute-3:   Logical volume "lv_ephemeral" successfully removed.
queue1-st-compute-4:   Logical volume "lv_ephemeral" successfully removed.
```

Verify the logical volume was removed:
```sh
$ pdsh "lsblk -o NAME,TYPE,MOUNTPOINT | sort" | dshbak -c
----------------
queue1-st-compute-[1-4]
----------------
NAME        TYPE MOUNTPOINT
nvme0n1     disk
├─nvme0n1p1 part
├─nvme0n1p2 part /boot/efi
└─nvme0n1p3 part /
nvme1n1     disk
```

The above output shows no partitions or logical volumes under the Instance Store `nvme1n1` disk device.


