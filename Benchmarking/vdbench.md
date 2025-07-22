# VDBench

Here are the details for running vdbench. It's an Oracle tool and Java based, so you need to download it from Oracle (free login needed) and install JRE on the instance before you can run.

Here is the Lustre site for running vdbench: http://wiki.lustre.org/VDBench (my instructions below are similar, but eliminate unnecessary steps).

## Download 

Download vdbench zip file from here, and move it over to the instance:
   https://www.oracle.com/technetwork/server-storage/vdbench-downloads-1901681.html


## Install JRE on the instance

```
$ sudo yum install jre -y
```

## Install vdbench

```
$ mkdir vdbench
$ cd vdbench
$ unzip vdbench<version>.zip
```

## Do an initial test

```
$ ./vdbench -t
```

## Create the test file specific to Samsung tests

```
$ cat verilog_test

#total 20ea : getattr 15%(3ea), setattr 5%(1ea), read 65%(13ea), write 15%(3ea)
hd=aws-verilog,system=ip-172-31-2-169,jvms=24,user=root,shell=vdbench
fsd=fsd_$host,anchor=/nfs1/test1,depth=1,width=1000,files=1000,size=1m
fwd=default,xfersize=16K,fileio=random,fileselect=random,threads=2
fwd=fwd$host_1,host=$host,fsd=fsd_$host,operation=getattr
fwd=fwd$host_2,host=$host,fsd=fsd_$host,operation=getattr
fwd=fwd$host_3,host=$host,fsd=fsd_$host,operation=getattr
fwd=fwd$host_4,host=$host,fsd=fsd_$host,operation=setattr
fwd=fwd$host_5,host=$host,fsd=fsd_$host,operation=read
fwd=fwd$host_6,host=$host,fsd=fsd_$host,operation=read
fwd=fwd$host_7,host=$host,fsd=fsd_$host,operation=read
fwd=fwd$host_8,host=$host,fsd=fsd_$host,operation=read
fwd=fwd$host_9,host=$host,fsd=fsd_$host,operation=read
fwd=fwd$host_10,host=$host,fsd=fsd_$host,operation=read
fwd=fwd$host_11,host=$host,fsd=fsd_$host,operation=read
fwd=fwd$host_12,host=$host,fsd=fsd_$host,operation=read
fwd=fwd$host_13,host=$host,fsd=fsd_$host,operation=read
fwd=fwd$host_14,host=$host,fsd=fsd_$host,operation=read
fwd=fwd$host_15,host=$host,fsd=fsd_$host,operation=read
fwd=fwd$host_16,host=$host,fsd=fsd_$host,operation=read
fwd=fwd$host_17,host=$host,fsd=fsd_$host,operation=read
fwd=fwd$host_18,host=$host,fsd=fsd_$host,operation=write
fwd=fwd$host_19,host=$host,fsd=fsd_$host,operation=write
fwd=fwd$host_20,host=$host,fsd=fsd_$host,operation=write
rd=rd1,fwd=fwd*,fwdrate=(10000-200000,10000),format=yes,elapsed=300,pause=180,interval=5
```

## Run the benchmark

This took over eight hours to complete using an NFS file system on a EC2 instance.

```
./vdbench -f verilog_test
```

Examples results:

```
Copyright (c) 2000, 2018, Oracle and/or its affiliates. All rights reserved.
Vdbench distribution: vdbench50407 Tue June 05 9:49:29 MDT 2018
For documentation, see 'vdbench.pdf'.
07:21:38.951 input argument scanned: '-fverilog_test'
07:21:39.138 Anchor size: anchor=/nfs1/test1: dirs: 1,000; files: 1,000,000; bytes: 976.563g (1,048,576,000,000)
07:21:43.387 Starting slave: /mnt/efs/vdbench/vdbench SlaveJvm -m 172.31.2.169 -n ip-172-31-2-169-10-190215-07.21.34.753 -l aws-verilog-0 -p 5570
07:21:43.407 Starting slave: /mnt/efs/vdbench/vdbench SlaveJvm -m 172.31.2.169 -n ip-172-31-2-169-11-190215-07.21.34.753 -l aws-verilog-1 -p 5570
07:21:43.427 Starting slave: /mnt/efs/vdbench/vdbench SlaveJvm -m 172.31.2.169 -n ip-172-31-2-169-20-190215-07.21.34.753 -l aws-verilog-10 -p 5570
07:21:43.447 Starting slave: /mnt/efs/vdbench/vdbench SlaveJvm -m 172.31.2.169 -n ip-172-31-2-169-21-190215-07.21.34.753 -l aws-verilog-11 -p 5570
07:21:43.467 Starting slave: /mnt/efs/vdbench/vdbench SlaveJvm -m 172.31.2.169 -n ip-172-31-2-169-22-190215-07.21.34.753 -l aws-verilog-12 -p 5570
07:21:43.488 Starting slave: /mnt/efs/vdbench/vdbench SlaveJvm -m 172.31.2.169 -n ip-172-31-2-169-23-190215-07.21.34.753 -l aws-verilog-13 -p 5570
07:21:43.508 Starting slave: /mnt/efs/vdbench/vdbench SlaveJvm -m 172.31.2.169 -n ip-172-31-2-169-24-190215-07.21.34.753 -l aws-verilog-14 -p 5570
07:21:43.528 Starting slave: /mnt/efs/vdbench/vdbench SlaveJvm -m 172.31.2.169 -n ip-172-31-2-169-25-190215-07.21.34.753 -l aws-verilog-15 -p 5570
07:21:43.549 Starting slave: /mnt/efs/vdbench/vdbench SlaveJvm -m 172.31.2.169 -n ip-172-31-2-169-26-190215-07.21.34.753 -l aws-verilog-16 -p 5570
07:21:43.569 Starting slave: /mnt/efs/vdbench/vdbench SlaveJvm -m 172.31.2.169 -n ip-172-31-2-169-27-190215-07.21.34.753 -l aws-verilog-17 -p 5570
07:21:43.589 Starting slave: /mnt/efs/vdbench/vdbench SlaveJvm -m 172.31.2.169 -n ip-172-31-2-169-28-190215-07.21.34.753 -l aws-verilog-18 -p 5570
07:21:43.609 Starting slave: /mnt/efs/vdbench/vdbench SlaveJvm -m 172.31.2.169 -n ip-172-31-2-169-29-190215-07.21.34.753 -l aws-verilog-19 -p 5570
07:21:43.630 Starting slave: /mnt/efs/vdbench/vdbench SlaveJvm -m 172.31.2.169 -n ip-172-31-2-169-12-190215-07.21.34.753 -l aws-verilog-2 -p 5570
07:21:43.650 Starting slave: /mnt/efs/vdbench/vdbench SlaveJvm -m 172.31.2.169 -n ip-172-31-2-169-30-190215-07.21.34.753 -l aws-verilog-20 -p 5570
07:21:43.671 Starting slave: /mnt/efs/vdbench/vdbench SlaveJvm -m 172.31.2.169 -n ip-172-31-2-169-31-190215-07.21.34.753 -l aws-verilog-21 -p 5570
07:21:43.691 Starting slave: /mnt/efs/vdbench/vdbench SlaveJvm -m 172.31.2.169 -n ip-172-31-2-169-32-190215-07.21.34.753 -l aws-verilog-22 -p 5570
07:21:43.711 Starting slave: /mnt/efs/vdbench/vdbench SlaveJvm -m 172.31.2.169 -n ip-172-31-2-169-33-190215-07.21.34.753 -l aws-verilog-23 -p 5570
07:21:43.731 Starting slave: /mnt/efs/vdbench/vdbench SlaveJvm -m 172.31.2.169 -n ip-172-31-2-169-13-190215-07.21.34.753 -l aws-verilog-3 -p 5570
07:21:43.751 Starting slave: /mnt/efs/vdbench/vdbench SlaveJvm -m 172.31.2.169 -n ip-172-31-2-169-14-190215-07.21.34.753 -l aws-verilog-4 -p 5570
07:21:43.772 Starting slave: /mnt/efs/vdbench/vdbench SlaveJvm -m 172.31.2.169 -n ip-172-31-2-169-15-190215-07.21.34.753 -l aws-verilog-5 -p 5570
07:21:43.792 Starting slave: /mnt/efs/vdbench/vdbench SlaveJvm -m 172.31.2.169 -n ip-172-31-2-169-16-190215-07.21.34.753 -l aws-verilog-6 -p 5570
07:21:43.813 Starting slave: /mnt/efs/vdbench/vdbench SlaveJvm -m 172.31.2.169 -n ip-172-31-2-169-17-190215-07.21.34.753 -l aws-verilog-7 -p 5570
07:21:43.833 Starting slave: /mnt/efs/vdbench/vdbench SlaveJvm -m 172.31.2.169 -n ip-172-31-2-169-18-190215-07.21.34.753 -l aws-verilog-8 -p 5570
07:21:43.853 Starting slave: /mnt/efs/vdbench/vdbench SlaveJvm -m 172.31.2.169 -n ip-172-31-2-169-19-190215-07.21.34.753 -l aws-verilog-9 -p 5570
07:21:44.076 All slaves are now connected
07:21:49.001 Starting RD=format_for_rd1

Feb 15, 2019 ..Interval.. .ReqstdOps... ...cpu%... read ....read..... ....write.... ..mb/sec... mb/sec .xfer.. ...mkdir.... ...rmdir.... ...create... ....open.... ...close.... ...delete... ..getattr... ..setattr...
 rate resp total sys pct rate resp rate resp read write total size rate resp rate resp rate resp rate resp rate resp rate resp rate resp rate resp
07:21:54.033 1 0.0 0.000 16.1 1.36 0.0 0.0 0.000 0.0 0.000 0.00 0.00 0.00 0 0.0 0.000 15.0 0.460 0.0 0.000 0.0 0.000 0.0 0.000 7743 0.981 0.0 0.000 0.0 0.000
07:21:59.006 2 0.0 0.000 2.1 1.93 0.0 0.0 0.000 0.0 0.000 0.00 0.00 0.00 0 0.0 0.000 15.0 0.449 0.0 0.000 0.0 0.000 0.0 0.000 6425 1.228 0.0 0.000 0.0 0.000
07:22:04.006 3 0.0 0.000 2.8 2.60 0.0 0.0 0.000 0.0 0.000 0.00 0.00 0.00 0 0.0 0.000 13.4 0.496 0.0 0.000 0.0 0.000 0.0 0.000 8018 0.985 0.0 0.000 0.0 0.000
07:22:09.005 4 0.0 0.000 3.0 2.71 0.0 0.0 0.000 0.0 0.000 0.00 0.00 0.00 0 0.0 0.000 19.6 0.538 0.0 0.000 0.0 0.000 0.0 0.000 8633 0.914 0.0 0.000 0.0 0.000
07:22:14.006 5 0.0 0.000 2.8 2.69 0.0 0.0 0.000 0.0 0.000 0.00 0.00 0.00 0 0.0 0.000 15.4 0.445 0.0 0.000 0.0 0.000 0.0 0.000 8458 0.934 0.0 0.000 0.0 0.000
07:22:19.004 6 0.0 0.000 3.0 2.90 0.0 0.0 0.000 0.0 0.000 0.00 0.00 0.00 0 0.0 0.000 18.2 0.477 0.0 0.000 0.0 0.000 0.0 0.000 8551 0.922 0.0 0.000 0.0 0.000
07:22:19.208 aws-verilog-0: anchor=/nfs1/test1 deleted 240903 files; 8024/sec
07:22:24.004 7 0.0 0.000 3.1 2.96 0.0 0.0 0.000 0.0 0.000 0.00 0.00 0.00 0 0.0 0.000 15.4 0.432 0.0 0.000 0.0 0.000 0.0 0.000 8335 0.947 0.0 0.000 0.0 0.000
07:22:29.004 8 0.0 0.000 2.7 2.61 0.0 0.0 0.000 0.0 0.000 0.00 0.00 0.00 0 0.0 0.000 18.6 0.467 0.0 0.000 0.0 0.000 0.0 0.000 8361 0.944 0.0 0.000 0.0 0.000

**** --- snip --- ****

09:31:51.327
09:31:51.327 Miscellaneous statistics:
09:31:51.327 (These statistics do not include activity between the last reported interval and shutdown.)
09:31:51.327 READ_OPENS Files opened for read activity: 81,271 270/sec
09:31:51.327 WRITE_OPENS Files opened for write activity: 18,764 62/sec
09:31:51.327 FILE_BUSY File busy: 63 0/sec
09:31:51.327 GET_ATTR Getattr requests: 1,201,779 4,005/sec
09:31:51.327 SET_ATTR Setattr requests: 397,705 1,325/sec
09:31:51.327 FILE_CLOSES Close requests: 100,007 333/sec
09:31:51.327
09:31:51.343 Waiting 180 seconds; requested by 'pause' parameter
09:34:53.001 Starting RD=format_for_rd1

**** --- snip --- ****
```