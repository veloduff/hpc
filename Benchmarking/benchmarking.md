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
# -C         : reorderTasksConstant – reorders tasks by a constant node offset for writing/reading neighbor’s data from different nodes (default: 0)
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

> [!WARNING] Do **not** stripe across all disks for high IOPS workloads.

## Lusture results

#### FSx Lustre

192K IOPS, 96 TB, 16 MDTS on 16 MDSs, with 80 OSTs (each 1.2TB) across 40 OSSs

```sh
        10      4500.00     4500.168       1.397    80546.904    41802.186    38744.718   300    5    10       3424        22103       110515       110515       120562        EDA
        20      9000.00     9000.438       1.422   160694.755    83683.431    77011.324   300   10    10       3424        22103       221031       221031       241125        EDA
        30     13500.00    13500.590       1.490   241306.215   125336.016   115970.199   300   15    10       3424        22103       331546       331546       361687        EDA
        40     18000.00    18000.776       1.562   322343.536   167508.186   154835.350   300   16    12       3424        27628       442062       442062       482250        EDA
        50     22500.00    22500.965       1.606   402415.426   209015.632   193399.794   300   16    15       3424        34536       552578       552578       602812        EDA
        60     27000.00    27001.111       1.667   483438.640   250933.371   232505.270   300   16    18       3424        41443       663093       663093       723375        EDA
        70     31500.00    31501.139       1.758   563655.001   292579.897   271075.104   300   16    21       3424        48350       773609       773609       843937        EDA
        80     36000.00    36001.406       1.799   644744.205   334578.859   310165.346   300   16    25       3424        55257       884125       884125       964500        EDA
        90     40500.00    40501.372       1.853   725572.328   376431.504   349140.823   300   16    28       3424        62165       994640       994640      1085062        EDA
       100     45000.00    45001.449       1.982   805989.323   417905.711   388083.612   300   16    31       3424        69072      1105156      1105156      1205625        EDA
```


#### Run 1

```sh
headnode_instance_type: "m6idn.2xlarge"
mgs_instance_type: "m6idn.xlarge"
mgs_min_count: 1
mgs_max_count: 1
mds_instance_type: "m6idn.2xlarge"
mds_min_count: 6 
mds_max_count: 8 
oss_instance_type: "m6idn.2xlarge"
oss_min_count: 40 
oss_max_count: 64 
batch_instance_type: "m6idn.xlarge"
batch_min_count: 16
batch_max_count: 64

# Settings for MGT 
# MGT will be mirrored volumes
MGT_SIZE=1                         # Size (GB) for MGT volumes
MGT_VOLUME_TYPE="gp3"              # Volume type for MDT (io1, io2, gp3)
MGT_THROUGHPUT=125                 # MDT Throughput in MiB/s
MGT_IOPS=3000                      # MDT IOPS

# Settings for MDTs when *NOT* using local disk (see MDT_USE_LOCAL)
MDTS_PER_MDS=1                     # Number of MDTs to create per MDS server
MDT_VOLUME_TYPE="io2"              # Volume type for MDT (io1, io2, gp3)
MDT_THROUGHPUT=1000                # MDT Throughput in MiB/s
MDT_SIZE=512                       # Size (GB) for MDT volumes
MDT_IOPS=12000                     # MDT IOPS

# Settings for OSTs when *NOT* using local disk (see OST_USE_LOCAL)
OSTS_PER_OSS=2                     # Number of OSTs to create per OSS server
OST_VOLUME_TYPE="gp3"              # Volume type for OST (io1, io2, gp3) 
OST_THROUGHPUT=250                 # Throughput in MiB/s
OST_SIZE=1200                      # Size (GB) for OST volumes 
OST_IOPS=4000                      # IOPS


###
### Results
###
[ec2-user@ip-10-0-48-68 results]$ tail -100f sfssum_specsfs_test.txt
  Business    Requested     Achieved     Avg Lat       Total          Read        Write   Run    #    Cl   Avg File      Cl Data   Start Data    Init File     Max File   Workload       Valid
    Metric      Op Rate      Op Rate        (ms)        KBps          KBps         KBps   Sec   Cl  Proc    Size KB      Set MiB      Set MiB      Set MiB    Space MiB       Name         Run
        10      4500.00     4500.135       2.750    80686.055    41909.136    38776.919   300    5    10       3424        22103       110515       110515       120562        EDA
        20      9000.00     9000.245       2.889   160690.943    83544.708    77146.235   300   10    10       3424        22103       221031       221031       241125        EDA
        30     13500.00    13500.043       3.316   241257.123   125365.182   115891.941   300   15    10       3424        22103       331546       331546       361687        EDA
        40     18000.00    18000.470       3.467   322281.477   167511.107   154770.370   300   16    12       3424        27628       442062       442062       482250        EDA
        50     22500.00    22499.456       3.775   402896.532   209192.013   193704.519   300   16    15       3424        34536       552578       552578       602812        EDA
        60     27000.00    26999.708       3.912   483476.957   251253.891   232223.065   300   16    18       3424        41443       663093       663093       723375        EDA
        70     31500.00    31498.438       4.150   563816.720   292635.010   271181.711   300   16    21       3424        48350       773609       773609       843937        EDA
        80     36000.00    35997.733       4.342   643958.462   334274.419   309684.043   300   16    25       3424        55257       884125       884125       964500        EDA
        90     40500.00    40497.087       4.483   725563.239   376639.483   348923.756   300   16    28       3424        62165       994640       994640      1085062        EDA
       100     45000.00    44994.010       4.873   805826.258   418196.658   387629.600   300   16    31       3424        69072      1105156      1105156      1205625        EDA
```

#### Run 2

Changing the OST volume type to `io1`, everything else is the same as **Run 1**

```sh
headnode_instance_type: "m6idn.2xlarge"
mgs_instance_type: "m6idn.xlarge"
mgs_min_count: 1
mgs_max_count: 1
mds_instance_type: "m6idn.2xlarge"
mds_min_count: 6 
mds_max_count: 8 
oss_instance_type: "m6idn.2xlarge"
oss_min_count: 40 
oss_max_count: 64 
batch_instance_type: "m6idn.xlarge"
batch_min_count: 16
batch_max_count: 64

# Settings for MGT 
# MGT will be mirrored volumes
MGT_SIZE=1                         # Size (GB) for MGT volumes
MGT_VOLUME_TYPE="gp3"              # Volume type for MDT (io1, io2, gp3)
MGT_THROUGHPUT=125                 # MDT Throughput in MiB/s
MGT_IOPS=3000                      # MDT IOPS

# Settings for MDTs when *NOT* using local disk (see MDT_USE_LOCAL)
MDTS_PER_MDS=1                     # Number of MDTs to create per MDS server
MDT_VOLUME_TYPE="io2"              # Volume type for MDT (io1, io2, gp3)
MDT_THROUGHPUT=1000                # MDT Throughput in MiB/s
MDT_SIZE=512                       # Size (GB) for MDT volumes
MDT_IOPS=12000                     # MDT IOPS

# Settings for OSTs when *NOT* using local disk (see OST_USE_LOCAL)
OSTS_PER_OSS=2                     # Number of OSTs to create per OSS server
OST_VOLUME_TYPE="io1"              # Volume type for OST (io1, io2, gp3) 
OST_THROUGHPUT=250                 # Throughput in MiB/s
OST_SIZE=1200                      # Size (GB) for OST volumes 
OST_IOPS=4000                      # IOPS


##
## Results
##
  Business    Requested     Achieved     Avg Lat       Total          Read        Write   Run    #    Cl   Avg File      Cl Data   Start Data    Init File     Max File   Workload       Valid
    Metric      Op Rate      Op Rate        (ms)        KBps          KBps         KBps   Sec   Cl  Proc    Size KB      Set MiB      Set MiB      Set MiB    Space MiB       Name         Run
        10      4500.00     4500.214       2.232    80660.209    41978.630    38681.579   300    5    10       3424        22103       110515       110515       120562        EDA
        20      9000.00     9000.275       2.329   160660.565    83627.674    77032.891   300   10    10       3424        22103       221031       221031       241125        EDA
        30     13500.00    13500.366       2.634   241311.310   125529.555   115781.755   300   15    10       3424        22103       331546       331546       361687        EDA
        40     18000.00    18000.524       2.752   322090.497   167364.122   154726.375   300   16    12       3424        27628       442062       442062       482250        EDA
        50     22500.00    22500.350       2.977   402747.936   209107.744   193640.192   300   16    15       3424        34536       552578       552578       602812        EDA
        60     27000.00    27000.353       3.019   483288.162   251163.774   232124.388   300   16    18       3424        41443       663093       663093       723375        EDA
        70     31500.00    31500.931       3.245   564259.166   292880.645   271378.521   300   16    21       3424        48350       773609       773609       843937        EDA
        80     36000.00    36000.864       3.304   644333.666   334531.348   309802.317   300   16    25       3424        55257       884125       884125       964500        EDA
        90     40500.00    40500.400       3.473   725633.533   376668.197   348965.336   300   16    28       3424        62165       994640       994640      1085062        EDA
       100     45000.00    44999.294       3.696   805858.113   418021.337   387836.777   300   16    31       3424        69072      1105156      1105156      1205625        EDA

```


#### Run 3 

Changing the OST IOPS to 6000, everything else is the same as **Run 2**

```sh
headnode_instance_type: "m6idn.2xlarge"
mgs_instance_type: "m6idn.xlarge"
mgs_min_count: 1
mgs_max_count: 1
mds_instance_type: "m6idn.2xlarge"
mds_min_count: 6 
mds_max_count: 8 
oss_instance_type: "m6idn.2xlarge"
oss_min_count: 40 
oss_max_count: 64 
batch_instance_type: "m6idn.xlarge"
batch_min_count: 16
batch_max_count: 64

# Settings for MGT 
# MGT will be mirrored volumes
MGT_SIZE=1                         # Size (GB) for MGT volumes
MGT_VOLUME_TYPE="gp3"              # Volume type for MDT (io1, io2, gp3)
MGT_THROUGHPUT=125                 # MDT Throughput in MiB/s
MGT_IOPS=3000                      # MDT IOPS

# Settings for MDTs when *NOT* using local disk (see MDT_USE_LOCAL)
MDTS_PER_MDS=1                     # Number of MDTs to create per MDS server
MDT_VOLUME_TYPE="io2"              # Volume type for MDT (io1, io2, gp3)
MDT_THROUGHPUT=1000                # MDT Throughput in MiB/s
MDT_SIZE=512                       # Size (GB) for MDT volumes
MDT_IOPS=12000                     # MDT IOPS

# Settings for OSTs when *NOT* using local disk (see OST_USE_LOCAL)
OSTS_PER_OSS=2                     # Number of OSTs to create per OSS server
OST_VOLUME_TYPE="io1"              # Volume type for OST (io1, io2, gp3) 
OST_THROUGHPUT=250                 # Throughput in MiB/s
OST_SIZE=1200                      # Size (GB) for OST volumes 
OST_IOPS=6000                      # IOPS


##
## Results - no difference
##

  Business    Requested     Achieved     Avg Lat       Total          Read        Write   Run    #    Cl   Avg File      Cl Data   Start Data    Init File     Max File   Workload       Valid
    Metric      Op Rate      Op Rate        (ms)        KBps          KBps         KBps   Sec   Cl  Proc    Size KB      Set MiB      Set MiB      Set MiB    Space MiB       Name         Run
        10      4500.00     4500.214       2.281    80632.552    42011.952    38620.599   300    5    10       3424        22103       110515       110515       120562        EDA
        20      9000.00     9000.346       2.371   160848.226    83717.929    77130.297   300   10    10       3424        22103       221031       221031       241125        EDA
        30     13500.00    13500.415       2.717   241045.441   125224.157   115821.284   300   15    10       3424        22103       331546       331546       361687        EDA
        40     18000.00    18000.605       2.801   321911.122   167180.369   154730.752   300   16    12       3424        27628       442062       442062       482250        EDA

(stopped the test)
```


#### Run 4

Changing the OST IOPS back to 4000, increasing the OST throughput from 250 to 500

```sh
headnode_instance_type: "m6idn.2xlarge"
mgs_instance_type: "m6idn.xlarge"
mgs_min_count: 1
mgs_max_count: 1
mds_instance_type: "m6idn.2xlarge"
mds_min_count: 6 
mds_max_count: 8 
oss_instance_type: "m6idn.2xlarge"
oss_min_count: 40 
oss_max_count: 64 
batch_instance_type: "m6idn.xlarge"
batch_min_count: 16
batch_max_count: 64

# Settings for MGT 
# MGT will be mirrored volumes
MGT_SIZE=1                         # Size (GB) for MGT volumes
MGT_VOLUME_TYPE="gp3"              # Volume type for MDT (io1, io2, gp3)
MGT_THROUGHPUT=125                 # MDT Throughput in MiB/s
MGT_IOPS=3000                      # MDT IOPS

# Settings for MDTs when *NOT* using local disk (see MDT_USE_LOCAL)
MDTS_PER_MDS=1                     # Number of MDTs to create per MDS server
MDT_VOLUME_TYPE="io2"              # Volume type for MDT (io1, io2, gp3)
MDT_THROUGHPUT=1000                # MDT Throughput in MiB/s
MDT_SIZE=512                       # Size (GB) for MDT volumes
MDT_IOPS=12000                     # MDT IOPS

# Settings for OSTs when *NOT* using local disk (see OST_USE_LOCAL)
OSTS_PER_OSS=2                     # Number of OSTs to create per OSS server
OST_VOLUME_TYPE="io1"              # Volume type for OST (io1, io2, gp3) 
OST_THROUGHPUT=500                 # Throughput in MiB/s
OST_SIZE=1200                      # Size (GB) for OST volumes 
OST_IOPS=4000                      # IOPS

##
## Results
##

  Business    Requested     Achieved     Avg Lat       Total          Read        Write   Run    #    Cl   Avg File      Cl Data   Start Data    Init File     Max File   Workload       Valid
    Metric      Op Rate      Op Rate        (ms)        KBps          KBps         KBps   Sec   Cl  Proc    Size KB      Set MiB      Set MiB      Set MiB    Space MiB       Name         Run
        10      4500.00     4500.153       2.272    80479.521    41830.499    38649.022   300    5    10       3424        22103       110515       110515       120562        EDA
        20      9000.00     9000.400       2.344   160816.714    83818.458    76998.256   300   10    10       3424        22103       221031       221031       241125        EDA
        30     13500.00    13500.327       2.696   241411.446   125347.578   116063.868   300   15    10       3424        22103       331546       331546       361687        EDA
        40     18000.00    18000.589       2.785   322033.221   167420.561   154612.660   300   16    12       3424        27628       442062       442062       482250        EDA
        50     22500.00    22500.734       2.978   402693.603   209262.162   193431.441   300   16    15       3424        34536       552578       552578       602812        EDA
        60     27000.00    27000.655       3.048   483847.573   251268.084   232579.488   300   16    18       3424        41443       663093       663093       723375        EDA
        70     31500.00    31500.575       3.265   563665.775   292601.260   271064.515   300   16    21       3424        48350       773609       773609       843937        EDA
        80     36000.00    36000.775       3.381   644381.679   334360.119   310021.560   300   16    25       3424        55257       884125       884125       964500        EDA
        90     40500.00    40500.248       3.524   724706.632   376185.977   348520.655   300   16    28       3424        62165       994640       994640      1085062        EDA
       100     45000.00    44999.999       3.732   805841.665   418260.971   387580.694   300   16    31       3424        69072      1105156      1105156      1205625        EDA


```





=======================

New runs

#### "large" file system

```sh
  Business    Requested     Achieved     Avg Lat       Total          Read        Write   Run    #    Cl   Avg File      Cl Data   Start Data    Init File     Max File   Workload       Valid
    Metric      Op Rate      Op Rate        (ms)        KBps          KBps         KBps   Sec   Cl  Proc    Size KB      Set MiB      Set MiB      Set MiB    Space MiB       Name         Run
        10      4500.00     4500.157       2.209    80668.121    42036.680    38631.441   300    5    10       3424        22103       110515       110515       120562        EDA
        20      9000.00     9000.342       2.301   160591.317    83641.160    76950.157   300   10    10       3424        22103       221031       221031       241125        EDA
        30     13500.00    13500.524       2.609   241155.817   125425.245   115730.572   300   15    10       3424        22103       331546       331546       361687        EDA
        40     18000.00    18000.679       2.726   322263.531   167584.425   154679.107   300   16    12       3424        27628       442062       442062       482250        EDA
        50     22500.00    22500.573       2.940   402634.787   209157.434   193477.352   300   16    15       3424        34536       552578       552578       602812        EDA
        60     27000.00    27000.683       2.993   483535.721   250963.239   232572.482   300   16    18       3424        41443       663093       663093       723375        EDA
        70     31500.00    31500.815       3.194   563808.135   293040.962   270767.173   300   16    21       3424        48350       773609       773609       843937        EDA
        80     36000.00    36000.920       3.299   644730.476   334682.902   310047.574   300   16    25       3424        55257       884125       884125       964500        EDA
        90     40500.00    40500.695       3.462   725261.218   376184.982   349076.236   300   16    28       3424        62165       994640       994640      1085062        EDA
       100     45000.00    45000.273       3.704   806419.128   418655.871   387763.257   300   16    31       3424        69072      1105156      1105156      1205625        EDA
       110     49500.00    49499.971       3.609   886977.712   460132.976   426844.736   300   16    34       3424        75979      1215671      1215671      1326187        EDA
       120     54000.00    53999.187       3.784   966642.660   501357.759   465284.901   300   16    37       3424        82886      1326187      1326187      1446750        EDA
       130     58500.00    58499.303       3.963  1048702.814   544393.124   504309.690   300   16    40       3424        89793      1436703      1436703      1567312        EDA
       140     63000.00    62998.013       4.045  1128840.865   586061.847   542779.019   300   16    43       3424        96701      1547218      1547218      1687875        EDA
       150     67500.00    67498.063       4.233  1209220.740   627405.106   581815.633   300   16    46       3424       103608      1657734      1657734      1808437        EDA
       160     72000.00    71996.597       4.336  1289437.173   669254.319   620182.854   300   16    50       3424       110515      1768250      1768250      1929000        EDA
       170     76500.00    76496.351       4.472  1369062.469   710472.733   658589.736   300   16    53       3424       117422      1878765      1878765      2049562        EDA
       180     81000.00    80991.362       4.597  1450521.976   752378.025   698143.951   300   16    56       3424       124330      1989281      1989281      2170125        EDA
       190     85500.00    85491.123       4.729  1531183.568   794142.329   737041.239   300   16    59       3424       131237      2099796      2099796      2290687        EDA
       200     90000.00    89992.126       4.787  1611394.770   835933.071   775461.699   300   16    62       3424       138144      2210312      2210312      2411250        EDA
       210     94500.00    94488.702       4.898  1692965.483   878619.925   814345.558   300   16    65       3424       145051      2320828      2320828      2531812        EDA
       220     99000.00    98983.680       5.089  1773005.469   919715.261   853290.208   300   16    68       3424       151958      2431343      2431343      2652375        EDA
       230    103500.00   103483.451       5.184  1854196.461   961944.954   892251.507   300   16    71       3424       158866      2541859      2541859      2772937        EDA
       240    108000.00   107982.795       5.317  1934802.921  1003934.342   930868.579   300   16    75       3424       165773      2652375      2652375      2893500        EDA
       250    112500.00   112477.345       5.410  2015781.883  1045660.498   970121.386   300   16    78       3424       172680      2762890      2762890      3014062        EDA
       260    117000.00   116970.275       5.601  2094612.509  1086568.156  1008044.354   300   16    81       3424       179587      2873406      2873406      3134625        EDA
       270    121500.00   121469.316       5.753  2175163.652  1128895.738  1046267.914   300   16    84       3424       186495      2983921      2983921      3255187        EDA
       280    126000.00   125961.638       5.949  2256407.783  1171081.594  1085326.189   300   16    87       3424       193402      3094437      3094437      3375750        EDA
       290    130500.00   130449.111       6.194  2336237.028  1212607.969  1123629.058   300   16    90       3424       200309      3204953      3204953      3496312        EDA
       300    135000.00   134001.212       7.645  2407984.964  1248599.946  1159385.018   300   16    93       3424       207216      3315468      3315468      3616875        EDA INVALID_RUN
```

changed OST IOPS from 3000 to 1000

bad run

```sh
  Business    Requested     Achieved     Avg Lat       Total          Read        Write   Run    #    Cl   Avg File      Cl Data   Start Data    Init File     Max File   Workload       Valid
    Metric      Op Rate      Op Rate        (ms)        KBps          KBps         KBps   Sec   Cl  Proc    Size KB      Set MiB      Set MiB      Set MiB    Space MiB       Name         Run
        10      4500.00     4500.182       2.224    80709.053    41914.334    38794.719   300    5    10       3424        22103       110515       110515       120562        EDA
        20      9000.00     9000.323       2.306   160679.559    83649.863    77029.696   300   10    10       3424        22103       221031       221031       241125        EDA
        30     13500.00    13500.499       2.630   241459.531   125502.379   115957.152   300   15    10       3424        22103       331546       331546       361687        EDA
        40     18000.00    18000.475       2.742   322226.295   167629.651   154596.644   300   16    12       3424        27628       442062       442062       482250        EDA
        50     22500.00    22498.546       4.275   402550.369   209234.680   193315.689   300   16    15       3424        34536       552578       552578       602812        EDA
        60     27000.00    26988.178       5.776   483042.953   250657.148   232385.805   300   16    18       3424        41443       663093       663093       723375        EDA
        70     31500.00    31462.365       6.989   562397.942   292154.888   270243.054   300   16    21       3424        48350       773609       773609       843937        EDA
        80     36000.00    35608.939       7.741   630440.093   328027.165   302412.928   300   16    25       3424        55257       884125       884125       964500        EDA
        90     40500.00    39388.661       8.188   685050.730   358970.969   326079.761   300   16    28       3424        62165       994640       994640      1085062        EDA INVALID_RUN
```

changed OST IPS back to 3000, changed vol type to gp3 from io1

```sh
  Business    Requested     Achieved     Avg Lat       Total          Read        Write   Run    #    Cl   Avg File      Cl Data   Start Data    Init File     Max File   Workload       Valid
    Metric      Op Rate      Op Rate        (ms)        KBps          KBps         KBps   Sec   Cl  Proc    Size KB      Set MiB      Set MiB      Set MiB    Space MiB       Name         Run
        10      4500.00     4500.130       2.777    80647.076    41945.882    38701.194   300    5    10       3424        22103       110515       110515       120562        EDA
        20      9000.00     9000.267       2.880   160613.279    83573.456    77039.823   300   10    10       3424        22103       221031       221031       241125        EDA
        30     13500.00    13500.000       3.347   241317.762   125499.802   115817.960   300   15    10       3424        22103       331546       331546       361687        EDA
        40     18000.00    18000.081       3.515   321861.575   167368.705   154492.869   300   16    12       3424        27628       442062       442062       482250        EDA
        50     22500.00    22498.921       3.830   402824.337   209105.550   193718.786   300   16    15       3424        34536       552578       552578       602812        EDA
        60     27000.00    26999.886       3.922   483335.437   251287.889   232047.547   300   16    18       3424        41443       663093       663093       723375        EDA
        70     31500.00    31499.292       4.135   563737.257   292838.965   270898.292   300   16    21       3424        48350       773609       773609       843937        EDA
        80     36000.00    35996.591       4.367   644350.984   334238.716   310112.269   300   16    25       3424        55257       884125       884125       964500        EDA
        90     40500.00    40497.254       4.509   725156.252   376201.416   348954.836   300   16    28       3424        62165       994640       994640      1085062        EDA
       100     45000.00    44991.361       4.912   805407.546   417908.126   387499.420   300   16    31       3424        69072      1105156      1105156      1205625        EDA
       110     49500.00    49487.657       4.988   886510.869   459824.905   426685.963   300   16    34       3424        75979      1215671      1215671      1326187        EDA
       120     54000.00    53985.833       5.160   966812.929   501397.998   465414.931   300   16    37       3424        82886      1326187      1326187      1446750        EDA
       130     58500.00    58482.166       5.345  1047001.764   543399.339   503602.425   300   16    40       3424        89793      1436703      1436703      1567312        EDA
       140     63000.00    62977.919       5.509  1128030.448   585729.111   542301.337   300   16    43       3424        96701      1547218      1547218      1687875        EDA
       150     67500.00    67475.912       5.629  1208038.211   627075.522   580962.689   300   16    46       3424       103608      1657734      1657734      1808437        EDA
       160     72000.00    71966.323       5.768  1288101.178   668530.071   619571.107   300   16    50       3424       110515      1768250      1768250      1929000        EDA
       170     76500.00    76459.466       5.962  1368025.199   710098.644   657926.555   300   16    53       3424       117422      1878765      1878765      2049562        EDA
       180     81000.00    80951.638       6.158  1449317.509   751807.678   697509.831   300   16    56       3424       124330      1989281      1989281      2170125        EDA
       190     85500.00    85448.293       6.330  1529522.716   793887.676   735635.040   300   16    59       3424       131237      2099796      2099796      2290687        EDA
       200     90000.00    89932.942       6.460  1609483.753   834923.540   774560.214   300   16    62       3424       138144      2210312      2210312      2411250        EDA
       210     94500.00    94425.933       6.715  1691016.369   877675.131   813341.239   300   16    65       3424       145051      2320828      2320828      2531812        EDA
       220     99000.00    98910.440       6.939  1770712.511   919118.790   851593.721   300   16    68       3424       151958      2431343      2431343      2652375        EDA
       230    103500.00   103386.573       7.106  1851252.949   960481.822   890771.127   300   16    71       3424       158866      2541859      2541859      2772937        EDA
       240    108000.00   107883.420       7.290  1930344.468  1001311.035   929033.433   300   16    75       3424       165773      2652375      2652375      2893500        EDA
       250    112500.00   112379.379       7.477  2011631.283  1044352.166   967279.117   300   16    78       3424       172680      2762890      2762890      3014062        EDA
       260    117000.00   116859.242       7.721  2092177.318  1085968.655  1006208.663   300   16    81       3424       179587      2873406      2873406      3134625        EDA
       270    121500.00   121250.614       8.059  2168367.909  1125925.069  1042442.840   300   16    84       3424       186495      2983921      2983921      3255187        EDA
       280    126000.00   125506.336       8.255  2239640.962  1163607.467  1076033.495   300   16    87       3424       193402      3094437      3094437      3375750        EDA
       290    130500.00   129449.563       8.479  2300849.843  1197306.598  1103543.245   300   16    90       3424       200309      3204953      3204953      3496312        EDA
       300    135000.00   132941.327       8.756  2344326.591  1222784.418  1121542.173   300   16    93       3424       207216      3315468      3315468      3616875        EDA
```

#### "xlarge" file system

```sh
  Business    Requested     Achieved     Avg Lat       Total          Read        Write   Run    #    Cl   Avg File      Cl Data   Start Data    Init File     Max File   Workload       Valid
    Metric      Op Rate      Op Rate        (ms)        KBps          KBps         KBps   Sec   Cl  Proc    Size KB      Set MiB      Set MiB      Set MiB    Space MiB       Name         Run
        30     13500.00    13500.285       2.680   241318.223   125327.341   115990.882   300   15    10       3424        22103       331546       331546       361687        EDA
        60     27000.00    26999.788       3.345   483279.803   251048.268   232231.534   300   16    18       3424        41443       663093       663093       723375        EDA
        90     40500.00    40500.015       3.646   725581.642   376413.527   349168.115   300   16    28       3424        62165       994640       994640      1085062        EDA
       120     54000.00    53999.165       3.950   967211.651   501982.706   465228.945   300   16    37       3424        82886      1326187      1326187      1446750        EDA
       150     67500.00    67498.388       4.378  1209109.696   627606.206   581503.490   300   16    46       3424       103608      1657734      1657734      1808437        EDA
       180     81000.00    80991.106       4.918  1450224.947   752925.401   697299.546   300   16    56       3424       124330      1989281      1989281      2170125        EDA
       210     94500.00    94486.233       5.303  1692870.425   878557.470   814312.955   300   16    65       3424       145051      2320828      2320828      2531812        EDA
       240    108000.00   107977.696       5.775  1934780.859  1003499.261   931281.597   300   16    75       3424       165773      2652375      2652375      2893500        EDA
       270    121500.00   121454.250       6.248  2175212.876  1129032.696  1046180.180   300   16    84       3424       186495      2983921      2983921      3255187        EDA
       300    135000.00   134927.140       6.673  2415484.620  1254134.410  1161350.211   300   16    93       3424       207216      3315468      3315468      3616875        EDA
       330    148500.00   148399.975       7.303  2657853.954  1379191.470  1278662.484   300   16   103       3424       227938      3647015      3647015      3978562        EDA
       360    162000.00   161856.737       7.976  2897995.746  1503157.701  1394838.045   300   16   112       3424       248660      3978562      3978562      4340250        EDA
       390    175500.00   175003.779       8.899  3127656.634  1624582.050  1503074.584   300   16   121       3424       269381      4310109      4310109      4701937        EDA
       420    189000.00   184659.513       9.948  3231001.957  1689827.654  1541174.303   300   16   131       3424       290103      4641656      4641656      5063625        EDA INVALID_RUN
       450    202500.00   192440.157      11.131  3268878.497  1727496.864  1541381.633   300   16   140       3424       310825      4973203      4973203      5425312        EDA INVALID_RUN
       480    216000.00   197541.010      12.682  3231802.463  1730482.190  1501320.273   300   16   150       3424       331546      5304750      5304750      5787000        EDA INVALID_RUN
       510    229500.00   193126.244      14.198  3155474.085  1689959.366  1465514.719   300   16   159       3424       352268      5636296      5636296      6148687        EDA INVALID_RUN
```
