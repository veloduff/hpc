# HPC Benchmarking Suite

## Overview

This directory contains comprehensive benchmarking tools and documentation for evaluating High Performance Computing (HPC) parallel filesystem performance. The benchmarking suite focuses on two primary tools: **IOR** (I/O Reference) for parallel I/O testing and **SPECsfs 2014 SP2** for industry-standard filesystem benchmarking with EDA (Electronic Design Automation) workloads.

## Key Features

- **IOR Benchmarking**: Parallel I/O performance testing with multiple APIs (POSIX, MPIIO, HDF5)
- **SPECsfs 2014 SP2**: Industry-standard filesystem benchmarking with EDA workload simulation
- **Automated Setup Scripts**: Streamlined installation and configuration processes
- **Performance Analysis**: Comprehensive results analysis and reporting capabilities
- **Lustre Optimization**: Specialized configurations and tuning for Lustre parallel filesystems

## Quick Start

1. **IOR Testing**: Use `run_ior_benchmark.sh` for automated IOR benchmark execution
2. **SPECsfs Setup**: Run `setup_specsfs.sh` for automated SPECsfs installation and configuration
3. **Results Analysis**: Review performance metrics and optimization recommendations in the results sections

## Supported Filesystems

- **Lustre**: Optimized configurations with ZFS backend
- **FSx for Lustre**: AWS managed Lustre filesystem testing
- **GPFS/Spectrum Scale**: IBM parallel filesystem support
- **General POSIX**: Standard filesystem compatibility

---

# Benchmarking


## IOR

Documentation: https://ior.readthedocs.io

The latest release for IOR is here: https://github.com/hpc/ior/releases

Download and extract
```sh
$ wget https://github.com/hpc/ior/releases/download/4.0.0/ior-4.0.0.tar.gz
$ tar xvf ior-4.0.0.tar.gz
```

Configure the make process, optionally use the GPFS library for the build
```sh
$ cd ior-4.0.0
$ ./configure
```

The `configure` should pick up the GPFS libraries, in the out you should see this:
```sh
...
checking for gpfs.h... yes
checking gpfs_fcntl.h usability... yes
checking gpfs_fcntl.h presence... yes
checking for gpfs_fcntl.h... yes
checking for library containing gpfs_fcntl... -lgpfs
checking for gpfsFineGrainWriteSharing_t... yes
checking for gpfsFineGrainReadSharing_t... yes
checking for gpfsCreateSharing_t... yes
...
```

Run make:
```.sh
$ make
```

```sh
$ sudo cp src/ior /usr/local/bin/
```


## IOR File System Benchmark Test Documentation

### Overview
This below script runs IOR (I/O Reference) benchmarks to test parallel file system performance using SLURM workload manager. The test performs both read and write operations with verification.

### Slurm batch Configuration
```bash
#SBATCH -J ior_test                     # Job name
#SBATCH -o /home/ec2-user/ior_test.out  # Output file
#SBATCH -e /home/ec2-user/ior_test.err  # Error file
#SBATCH --exclusive                     # Exclusive node access
#SBATCH --nodes=4                       # Number of nodes
#SBATCH --ntasks-per-node=1             # Tasks per node
```

### Module Management
The script manages MPI modules:
```bash
module list  # Display currently loaded modules
```
Note: Intel MPI loading is commented out but can be enabled by uncommenting:
```bash
#module purge
#module load intelmpi
```

### Available IOR parameters

Example ior command:
```sh
ior -w -W -r -R -t 1M -e -o /gpfs/gpfs1/testDir1/testFile -i 1 --posix.odirect -b 10g -F -v
```

#### Basic Operations
- `-w`: Write file
- `-W`: Verify write operation
- `-r`: Read file
- `-R`: Verify read operation
- `-e`: Perform fsync on write close

#### Size Parameters
- `-t <size>`: Transfer size (8, 4k, 2m, 1g)
- `-b <size>`: Block size per task (8, 4k, 2m, 1g)

#### Test Configuration
- `-o <path>`: Test file path
- `-i <num>`: Number of test iterations
- `-a <api>`: I/O API selection:
  - POSIX
  - MPIIO
  - HDF5
  - HDFS
  - S3
  - S3_EMC
  - NCMPI
  - RADOS
- `-F`: File-per-process mode
- `-v`: Verbose output (can be repeated)

#### Advanced Options
- `-z`: Random offset access
- `-T <minutes>`: Maximum test duration
- `-Z`: Random task ordering for readback
- `-C`: Constant task reordering
- `-X <num>`: Random seed for task reordering
  - Positive: Same seed for all iterations
  - Negative: Different seed per iteration

### Alternative Test Configurations
The script below includes commented examples of alternative test configurations:

1. Include these for random offset test:
   ```sh
   #-z -X 1 -Z
   ```

2. Basic MPIIO test:
   ```bash
   #ior -b 1g -t 1m -a MPIIO -w -r -F -i 1
   ```

### Best Practices
1. Ensure sufficient storage space is available
2. Run multiple iterations for consistent results
3. Monitor system resources during tests
4. Clean cache between tests if needed
5. Verify permissions on test directories
6. Consider using different block sizes based on the file system
7. Use direct I/O (--posix.odirect) to bypass cache when needed

### Output
- Test results will be written to `/home/ec2-user/ior_test.out`
- Errors will be logged to `/home/ec2-user/ior_test.err`

### Complete Slurm batch file with ior command

Example

```sh
#!/bin/bash
#SBATCH -J ior_test
#SBATCH -o /home/ec2-user/ior_test.out
#SBATCH -e /home/ec2-user/ior_test.err
#SBATCH --exclusive
#SBATCH --nodes=4
#SBATCH --ntasks-per-node=1

# load Intel MPI
module purge
module load intelmpi
module list

# -w         : writeFile – write file
# -W         : checkWrite – check read after write
# -r         : readFile – read existing file
# -R         : checkRead – check read after read
# -t <num>   : transferSize – size of transfer in bytes (e.g.: 8, 4k, 2m, 1g), should match the block size of the file system
# -e         : fsync – perform fsync upon POSIX write close
# -o <str>   : testFile – full name for test
# -i <num>   : repetitions – number of repetitions of test
# -a <str>   : api – API for I/O [POSIX|MPIIO|HDF5|HDFS|S3|S3_EMC|NCMPI|RADOS]
# -b <num>   : blockSize – contiguous bytes to write per task (e.g.: 8, 4k, 2m, 1g), if using -F this is the file size
# -F         : filePerProc – file-per-process, use one file per process, the blocksize will be the size of each file
# -v         : verbose – output information (repeating flag increases level)
# -z         : randomOffset – access is to random, not sequential, offsets within a file
# -T <num>   : maxTimeDuration – max time in minutes to run tests
### Choose one of the following: reorderTasksRandom or reorderTasksConstant
# -Z         : reorderTasksRandom – changes task ordering to random ordering for readback
# -C         : reorderTasksConstant – reorders tasks by a constant node offset for writing/reading neighbor's data from different nodes (default: 0)
# -X <num>   : reorderTasksRandomSeed – random seed for -Z option, When > 0, use the same seed for all iterations, When < 0, different seed for each iteration

# With MPIIO
srun --mpi=pmix_v5 /usr/local/bin/ior -o /mnt/lustre/benchmarks/testFile -b 10g -t 1M -v -w -W -r -R -e -F -i 3 -a MPIIO

# With POSIX direct
#srun --mpi=pmix_v5 /usr/local/bin/ior -o /mnt/lustre/benchmarks/testFile -b 10g -t 1M -v -w -W -r -R -e -F -i 3 --posix.odirect

```

### Example ior output

```sh
IOR-4.0.0: MPI Coordinated Test of Parallel I/O
Began               : Tue Apr 29 14:12:28 2025
Command line        : /usr/local/bin/ior -w -W -r -R -t 1M -e -o /gpfs/gpfs1/testDir1/testFile -i 1 --posix.odirect -b 10g -F -v
Machine             : Linux queue1-st-t2micro-1
TestID              : 0
StartTime           : Tue Apr 29 14:12:28 2025
Path                : /gpfs/gpfs1/testDir1/testFile.00000000
FS                  : 882.9 GiB   Used FS: 0.3%   Inodes: 0.9 Mi   Used Inodes: 0.4%
Participating tasks : 4

Options:
api                 : POSIX
apiVersion          :
test filename       : /gpfs/gpfs1/testDir1/testFile
access              : file-per-process
type                : independent
segments            : 1
ordering in a file  : sequential
ordering inter file : no tasks offsets
nodes               : 4
tasks               : 4
clients per node    : 1
repetitions         : 1
xfersize            : 1 MiB
blocksize           : 10 GiB
aggregate filesize  : 40 GiB
verbose             : 1

Results:

access    bw(MiB/s)  IOPS       Latency(s)  block(KiB) xfer(KiB)  open(s)    wr/rd(s)   close(s)   total(s)   iter
------    ---------  ----       ----------  ---------- ---------  --------   --------   --------   --------   ----
Commencing write performance test: Tue Apr 29 14:12:28 2025
write     580.00     580.01     0.006896    10485760   1024.00    0.000648   70.62      0.000842   70.62      0
Verifying contents of the file(s) just written.
Tue Apr 29 14:13:39 2025

Commencing read performance test: Tue Apr 29 14:14:12 2025

read      1201.51    1201.51    0.003329    10485760   1024.00    0.000125   34.09      0.000241   34.09      0
remove    -          -          -           -          -          -          -          -          0.000564   0
Max Write: 580.00 MiB/sec (608.18 MB/sec)
Max Read:  1201.51 MiB/sec (1259.87 MB/sec)

Summary of all tests:
Operation   Max(MiB)   Min(MiB)  Mean(MiB)     StdDev   Max(OPs)   Min(OPs)  Mean(OPs)     StdDev    Mean(s) Stonewall(s) Stonewall(MiB) Test# #Tasks tPN reps fPP reord reordoff reordrand seed segcnt   blksiz    xsize aggs(MiB)   API RefNum
write         580.00     580.00     580.00       0.00     580.00     580.00     580.00       0.00   70.62058         NA            NA     0      4   1    1   1     0        1         0    0      1 10737418240  1048576   40960.0 POSIX      0
read         1201.51    1201.51    1201.51       0.00    1201.51    1201.51    1201.51       0.00   34.09051         NA            NA     0      4   1    1   1     0        1         0    0      1 10737418240  1048576   40960.0 POSIX      0
```


## SPECsfs 2014 SP2

### License info

A license is required to run SPEC SFS. See purchase options here: https://www.spec.org/order/

### Setup a Python virtual environment

Prior to installing or using SPEC SFS, you should have a known python environment, and using a virtual environment is probably the best way to do this:

Here is an example using `python3.11`:

```sh
$ mkdir ~/Envs

$ python3.11 -m venv ~/Envs/specsfs

$ source ~/Envs/specsfs/bin/activate

(specsfs) $ which python
~/Envs/.specsfs/bin/python

(specsfs) $ python --version
Python 3.11.11
```

### Install SPEC SFS 20214

The SPEC SFS package is distributed through an ISO file, currently the ISO is **SPECsfs2014_SP2.iso.** You will need to locally mount the ISO file and install from there **using the full path to the directory - note the directory can not already exists:**

```sh
$ sudo mkdir /mnt/iso
$ sudo mount -o loop SPECsfs2014_SP2.iso /mnt/iso
$ cd /mnt/iso
$ python SfsManager --install-dir=/mnt/efs/SPEC/SPECsfs/execute
Installing SPECsfs2014_SP2 to /mnt/efs/SPEC/SPECsfs/execute.
SPEC SFS2014_SP2 successfully installed.
```

You will also need to install matplotlib, for generating reports:

```sh
pip install matplotlib
```

Verify the install, you should see something like this:

```sh
$ cd /mnt/efs/SPEC/SPECsfs/execute
$ ls -l
total 460
-r-xr-xr-x 1 centos centos   3679 Nov 29  2017 benchmarks.xml
dr-xr-xr-x 8 centos centos   6144 Nov 29  2017 binaries
dr-xr-xr-x 4 centos centos   6144 Nov 29  2017 bin.in
-r-xr-xr-x 1 centos centos    805 Nov 29  2017 copyright.txt
dr-xr-xr-x 2 centos centos   6144 Nov 29  2017 docs
-r-xr-xr-x 1 centos centos   2750 Nov 29  2017 Example_run_script.sh
-r-xr-xr-x 1 centos centos   3653 Nov 29  2017 future_direction
-r-xr-xr-x 1 centos centos   1934 Nov 29  2017 Makefile
-r-xr-xr-x 1 centos centos   1292 Nov 29  2017 makefile.in
-r-xr-xr-x 1 centos centos    527 Nov 29  2017 Map_share_script
dr-xr-xr-x 2 centos centos   6144 Nov 29  2017 msbuild
dr-xr-xr-x 5 centos centos   6144 Nov 29  2017 netmist
-r-xr-xr-x 1 centos centos    462 Nov 29  2017 NOTICE
dr-xr-xr-x 3 centos centos   6144 Nov 29  2017 pdsm
-r-xr-xr-x 1 centos centos 130388 Nov 29  2017 rcschangelog.txt
-r-xr-xr-x 1 centos centos   2387 Nov 29  2017 README.md
dr-xr-xr-x 3 centos centos   6144 Nov 29  2017 redistributable_sources
-r-xr-xr-x 1 centos centos   1768 Nov 29  2017 sfs2014result.css
-r-xr-xr-x 1 centos centos    303 Nov 29  2017 sfs_ext_mon
-r-xr-xr-x 1 centos centos    578 Nov 29  2017 sfs_ext_mon.cmd
-r-xr-xr-x 1 centos centos  97797 Nov 29  2017 SfsManager
-r-xr-xr-x 1 centos centos   1720 Nov 29  2017 sfs_rc
-r-xr-xr-x 1 centos centos  12280 Nov 29  2017 SPEC_LICENSE.txt
-r-xr-xr-x 1 centos centos 130549 Nov 29  2017 SpecReport
-r-xr-xr-x 1 centos centos  10406 Nov 29  2017 submission_template.xml
dr-xr-xr-x 3 centos centos   6144 Nov 29  2017 win32lib
```

### Configuration - for EDA benchmark

In a separate directory (to keep binaries and results separated), copy the default **sfs_rc** file to the new location and update it for your tests:

```
mkdir -p /mnt/efs/SPEC/SPECsfs/specsfs_fsx-lustre/20190410
cd /mnt/efs/SPEC/SPECsfs/specsfs_fsx-lustre/20190410
cp /mnt/efs/SPEC/SPECsfs/execute/sfs_rc sfs_eda_rc
```

Edit that the `sfs_eda_rc` file, similar to below. Leave the other settings not shown here as their defaults:

```
BENCHMARK=EDA
LOAD=10
INCR_LOAD=10
NUM_RUNS=10
CLIENT_MOUNTPOINTS=spec_sfs.clients
EXEC_PATH=/mnt/efs/SPEC/SPECsfs/execute/binaries/linux/x86_64/netmist
USER=centos
#USER=ec2-user
WARMUP_TIME=300
IPV6_ENABLE=0
PRIME_MON_SCRIPT=
PRIME_MON_ARGS=
NETMIST_LOGS=
INIT_RATE=0
```

### Create the clients file

For the above `sfs_eda_rc` file, the `CLIENT_MOUNTPOINTS` variable is file name of the clients file.

An example clients file is below, **each entry is a job (a process on a core)**, and total jobs should equal the number of cores (with no HT) on the instance. This shows four jobs on each instance, but again you need should match the total number of cores on the instance, at least as a first test:

```
ip-172-31-12-80 /mnt/fsx/spec_sfs_test.d
ip-172-31-12-80 /mnt/fsx/spec_sfs_test.d
ip-172-31-12-80 /mnt/fsx/spec_sfs_test.d
ip-172-31-12-80 /mnt/fsx/spec_sfs_test.d
ip-172-31-1-209 /mnt/fsx/spec_sfs_test.d
ip-172-31-1-209 /mnt/fsx/spec_sfs_test.d
ip-172-31-1-209 /mnt/fsx/spec_sfs_test.d
ip-172-31-1-209 /mnt/fsx/spec_sfs_test.d
ip-172-31-15-18 /mnt/fsx/spec_sfs_test.d
ip-172-31-15-18 /mnt/fsx/spec_sfs_test.d
ip-172-31-15-18 /mnt/fsx/spec_sfs_test.d
ip-172-31-15-18 /mnt/fsx/spec_sfs_test.d
ip-172-31-11-187 /mnt/fsx/spec_sfs_test.d
ip-172-31-11-187 /mnt/fsx/spec_sfs_test.d
ip-172-31-11-187 /mnt/fsx/spec_sfs_test.d
ip-172-31-11-187 /mnt/fsx/spec_sfs_test.d
ip-172-31-3-108 /mnt/fsx/spec_sfs_test.d
ip-172-31-3-108 /mnt/fsx/spec_sfs_test.d
ip-172-31-3-108 /mnt/fsx/spec_sfs_test.d
ip-172-31-3-108 /mnt/fsx/spec_sfs_test.d
```

### Setup license file

Create the `netmist_license_key` file in either /tmp or in the current working directory where you will run the benchmark. This file should be a simple text file that contains:

```sh
LICENSE KEY #####
```

Where the ##### is the license number that you have received from SPEC.

### Run

Make sure the **license file, configuration file, and the clients file** are ready before running.

> [!WARNING]
> These benchmarks can run long, `screen` should be used to avoid unintended termination.

The `-s` is the label or prefix for the output.
```sh
$ screen

$ export E_DIR=/mnt/efs/SPEC/SPECsfs/execute

$ python $E_DIR/SfsManager -b $E_DIR/benchmarks.xml -r sfs_eda_rc -s eda_testing
```

This will have output to STDOUT, but you can also look in the `results` directory at the log file.

### Example output

The test results are in the `results` directory. The text results are in the `.txt` file, for 
example `sfssum_aws_eda_gpfs.txt`. For the example output below, the runs that are `INVALID_RUN` 
are where the `Requested Op Rate` and the `Achieved Op Rate` are not equal. In other words, the test
failed to achieve the intended `Op Rate`. Additionally, the `Avg Lat` increases as the `Requested Op Rate`
increases.

```sh
  Business    Requested     Achieved     Avg Lat       Total          Read        Write   Run    #    Cl   Avg File      Cl Data   Start Data    Init File     Max File   Workload       Valid
    Metric      Op Rate      Op Rate        (ms)        KBps          KBps         KBps   Sec   Cl  Proc    Size KB      Set MiB      Set MiB      Set MiB    Space MiB       Name         Run
        10      4500.00     4500.248       0.610    80456.669    41775.361    38681.308   300    3    16       3424        36838       110515       110515       120562        EDA
        20      9000.00     9000.415       0.730   160710.110    83570.027    77140.083   300    4    25       3424        55257       221031       221031       241125        EDA
        30     13500.00    13500.784       0.829   241333.310   125351.618   115981.692   300    4    37       3424        82886       331546       331546       361687        EDA
        40     18000.00    18000.966       0.981   322456.840   167539.042   154917.798   300    4    50       3424       110515       442062       442062       482250        EDA
        50     22500.00    22501.134       1.335   402467.001   209132.436   193334.565   300    4    62       3424       138144       552578       552578       602812        EDA
        60     27000.00    23613.540       8.129   454129.790   230594.346   223535.444   300    4    75       3424       165773       663093       663093       723375        EDA INVALID_RUN
        70     31500.00    20949.291      29.366   440837.355   217363.377   223473.978   300    4    87       3424       193402       773609       773609       843937        EDA INVALID_RUN
```

### Build report for submission

You will need to create the submission file before running the SpecReport command. Copy the submission_template.xml file from the install directory as the template, and chmod to allow for read/write.

```sh
$ cp /mnt/efs/SPEC/SPECsfs/execute/submission_template.xml aws_eda_submission.xml
$ chmod 755 aws_eda_submission.xml
```

Remove this comment on line 211 or you will see an error (Error parsing report XML file ... line 211 ...)

```sh
<!-- --------------------- DO NOT EDIT BELOW THIS LINE -------------------- -->
```

If you just want to generate a report that includes building the plots and the web page, change these values, some have multiple occurrences, you can use the sed commands below

```sh
licenseNumber="License Number"
ref="Diagram File Name"
<hardwareConfigAndTuning environmentType="physical|virtual">
usableGiB="Usable GiB of Item"
memorySizeGiB="Size in GiB"
memoryQuantity="Quantity"
```

Use this to replace the above values with valid values, so you can just make a report (but not for submission)

```sh
export SUB_FILE=aws_eda_submission.xml
sed -i 's/License Number/9033/' $SUB_FILE
sed -i 's/ref=\"Diagram File Name\"/ref=\"diagram.png\"/' $SUB_FILE
sed -i 's/environmentType=\"physical|virtual\"/environmentType=\"virtual\"/' $SUB_FILE
sed -i 's/usableGiB=\"Usable GiB of Item\"/usableGiB=\"1\"/' $SUB_FILE
sed -i 's/memorySizeGiB=\"Size in GiB\"/memorySizeGiB=\"1\"/' $SUB_FILE
sed -i 's/memoryQuantity=\"Quantity\"/memoryQuantity=\"1\"/' $SUB_FILE
touch diagram.png
```

Example command for report:

```sh
$ export E_DIR=/mnt/efs/SPEC/SPECsfs/execute
$ python $E_DIR/SpecReport -i aws_eda_submission.xml -r sfs_aws_eda.rc -s aws_fsx_eda

Submission package creation complete: sfs2014-20190411-0001.zip

```

Once you have downloaded the zip file, unzip it and open the html file.  You should see something like this:

[insert image here]

### Tuning SPECsfs

Although it would create an invalid test that can not be submitted to SPEC, the parameters of the
benchmark can be changed. In the top level SPEC directory, for example `/gpfs/gpfs1/SPEC/SPECsfs/execute`,
edit the `benchmarks.xml` file as needed. For example, `FILE_SIZE` can be tuned to fit a specific workload.
Here is the **EDA** benchmark section for reference, and each benchmark type will have it's own section 
(e.g., `VDI`, `SWBUILD`, `DATABASE`, etc.).

```xml
    <benchmark name="EDA" business_metric="JOB_SETS">
        <workload name="EDA_FRONTEND">
            <oprate>100</oprate>
            <instances>3</instances>
            <override_parm name="FILE_SIZE">16k</override_parm>
            <override_parm name="FILES_PER_DIR">10</override_parm>
            <override_parm name="DIR_COUNT">10</override_parm>
        </workload>
        <workload name="EDA_BACKEND">
            <oprate>75</oprate>
            <instances>2</instances>
            <override_parm name="FILE_SIZE">10m</override_parm>
            <override_parm name="FILES_PER_DIR">10</override_parm>
            <override_parm name="DIR_COUNT">5</override_parm>
        </workload>
        <override_parm name="RUNTIME">300</override_parm>
        <threshold type="proc oprate">75</threshold>
        <threshold type="global oprate">95</threshold>
        <threshold type="workload variance">5</threshold>
    </benchmark>
```

## Stripe across all disks

> [!WARNING] Do **not** stripe across all disks for high IOPS workloads.


### `dd` with and without stripe
Without setting stripe across all OSTs, the performance is 224 MB/s

```sh
[root@storage-mgs-mds-st-storage-mgs-mds-1 lustre]# dd if=/dev/zero of=file.10G bs=1M count=10000
10000+0 records in
10000+0 records out
10485760000 bytes (10 GB, 9.8 GiB) copied, 46.8361 s, 224 MB/s
```

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

Setting the stripe across all OSTs, the performance is 1.6 GB/s

```sh
$ dd if=/dev/zero of=with-stripe.10G bs=1M count=10000
10000+0 records in
10000+0 records out
10485760000 bytes (10 GB, 9.8 GiB) copied, 6.35695 s, 1.6 GB/s
```

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
