# NFS, SMB, CIFS and other file system protocols


**Overview**
* **NFS (Network File System)** is primarily used in Unix/Linux environments, offering stateless (NFSv3) or stateful (NFSv4) operations. 
* **SMB (Server Message Block)** and its predecessor **CIFS (Common Internet File System)** are primarily for Windows environments, 
  and provide file sharing, printer access, and authentication services. External tools like **Samba** are needed to access remote 
  Windows file servers from a Linux machine.
* Other protocols:
  *  **AFP (Apple Filing Protocol)** for macOS
  *  **FTP/SFTP** for file transfers
  *  **WebDAV** for web-based file access


## NFS vs SMB Comparison

<table>
  <thead>
    <tr>
      <th>Feature</th>
      <th>NFS</th>
      <th>SMB</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Best suited for</strong></td>
      <td>Linux-based network architectures</td>
      <td>Windows-based architectures</td>
    </tr>
    <tr>
      <td><strong>Shared resources</strong></td>
      <td>Files and directories</td>
      <td>Wide range of network resources, including file and print services, storage devices, and virtual machine storage</td>
    </tr>
  </tbody>
</table>

## NFSv3 vs NFSv4 

### Overview of Differences

For latency and metadata performance, application performance testing should be done with both NFS v3 and v4. The 
assumption can be made that v3 will do better for small files and metadata heavy workloads, but this may not be the case
for every application.

<table>
  <thead>
    <tr>
      <th style="width: 20%">Feature</th>
      <th style="width: 40%">NFSv3</th>
      <th style="width: 40%">NFSv4</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>Latency, and State Management</strong></td>
      <td>Lower latency, Stateless</td>
      <td>Stateful</td>
    </tr>
    <tr>
      <td><strong>Protocols</strong></td>
      <td>UDP or TCP</td>
      <td>TCP only</td>
    </tr>
    <tr>
      <td><strong>Locking</strong></td>
      <td>Locking is not built-in which is better for stateless<br> operations, but can use external (NLM)</td>
      <td>Built-in locking</td>
    </tr>
    <tr>
      <td><strong>Metadata and small files</strong></td>
      <td>Good for high metadata and many small files,<br> e.g., Faster with <code>ls, stat, find</code></td>
      <td>Better for throughput and large file performance</td> 
    </tr>
    <tr>
      <td><strong>System resources</strong></td>
      <td>Less CPU overhead on client and server</td>
      <td>More system resources used</td>
    </tr>
    <tr>
      <td><strong>Security</strong></td>
      <td>Not built-in (optional AUTH_SYS, Kerberos),<br> Multiple ports complicate firewall config</td>
      <td>Built-in Kerberos, integration with Active Directory, and rich ACL support</td>
    </tr>
    <tr>
      <td><strong>Ports</strong></td>
      <td>Multiple (111, 2049, random)</td>
      <td>Single port (2049), better security on firewalls</td>
    </tr>
    <tr>
      <td><strong>Operations</strong></td>
      <td>Simple RPC calls</td>
      <td>Compound operations, reduced network round trips, delegations improve caching (see below)</td>
    </tr>
    <tr>
      <td><strong>Caching</strong></td>
      <td>Basic</td>
      <td>Advanced delegations</td>
    </tr>
    <tr>
      <td><strong>Parallel Access</strong></td>
      <td>Not available or very limited</td>
      <td>pNFS parallel access, for high-throughput,<br> better scalability with multiple clients</td>
    </tr>
  </tbody>
</table>

### NFSv4 Delegations Explained

**Delegations** are NFSv4's mechanism for improving caching performance by granting clients temporary authority to manage files locally:

**How Delegations Work:**
- **Read Delegation**: Server tells client "you can cache this file's data and attributes locally - I'll notify you if another client wants to modify it"
- **Write Delegation**: Server tells client "you have exclusive access - cache writes locally and flush when done"

**Performance Benefits:**
- **Reduced Network Traffic**: Client can serve reads from local cache without contacting server
- **Faster Metadata Operations**: File attributes (size, timestamps) cached locally
- **Better Write Performance**: Multiple writes can be batched before sending to server
- **Consistency Guaranteed**: Server recalls delegations when other clients need access

**Summary**
* NFSv3 - **without delegations**: Every file read/stat results in a **network round trip**
* NFSv4 - **with delegations**: First access gets delegation subsequent **reads from local cache**


## NetApp ONTAP on AWS

**Single-AZ 2 is the second-generation file system that supports up to 12 HA pairs.**

### FSx for ONTAP File System Generations Comparison

**NOTE**: Only the **single AZ** second-generation file systems support **multiple HA pairs**. FSx NetApp ONTAP **can not do "multi-multi": multiple AZs with multiple HA pairs**.

| Feature                         | First-generation            | 1 HA Pair - second-generation  | Multiple HA pairs - second-generation         |
|---------------------------------|-----------------------------|--------------------------------|-----------------------------------------------|
| **Number of AZs**               | Single or Multiple          | Single or Multiple             | **Single AZ only**                            | 
| **Deployment type**             | SINGLE_AZ_1<br> MULTI_AZ_1  | SINGLE_AZ_2<br>MULTI_AZ_2      | SINGLE_AZ_2   ("_2" is for the generation)    |
| **HA pairs**                    | 1 HA pair                   | 1 HA pair                      | 1 – 12 HA pairs                               |
| **SSD storage**                 | 1 TiB up to 192 TiB         | 1 TiB up to 512 TiB            | 1 TiB up to 1 PiB (total)                     |
| **SSD IOPS**                    | 3 IOPS/GiB up to 200K       | 3 IOPS/GiB up to 200K          | 3 IOPS/GiB up to 2,400,000 (200K per HA pair) |
| **Throughput for one HA pair**  | 128 MB/s up to 4,096 MB/s   | 384 MB/s up to 6,144 MB/s      | 384 MB/s up to 6,144 MB/s (per HA pair)       |
| **Throughput total**            | Same as one HA pair         | Same as one HA pair            | 384 MB/s up to 73,728 MB/s (with 12 HA pairs) |

**NOTE**:
* Second-generation FSx for ONTAP file systems are available in the following AWS Regions: **US East (N. Virginia, Ohio), US West (N. California, Oregon), Europe (Frankfurt, Ireland), and Asia-Pacific (Sydney).**
* You can't change your file system's deployment type after creation.

**FSx for ONTAP Support:**
- Both NFSv3 and NFSv4.1 fully supported
- **FlexGroup volumes** work with both protocols
- **FlexCache** caching available for both versions
- **SnapMirror** replication supports both protocols

### EDA Workloads - Best Practices for FSx for ONTAP

**Mixed Environment Strategy:**
- **NFSv3** for `/home`, `/tools`, source repositories
- **NFSv4** for design databases, simulation results
- **Separate SVMs** for different workload types
- **Test both protocols** with your specific applications

#### nconnect Performance Enhancement

**NFSv4 with nconnect:**
- **Significant performance gains** (2-4x throughput improvement)
- Creates multiple TCP connections for parallel I/O
- Optimal values: 4-8 for metadata, 8-16 for throughput

**NFSv3 with nconnect:**
- **Limited benefit** - NFSv3 naturally uses multiple connections
- Generally not recommended

**Front-End Workloads (Metadata-Heavy):**
```bash
# NFSv3 - Better for home directories, tools, source code
mount -t nfs -o vers=3,rsize=65536,wsize=65536,hard,intr,timeo=600
```

**Back-End Workloads (High-Throughput):**
```bash
# NFSv4 with nconnect - Better for design databases, simulation results
mount -t nfs -o vers=4.1,nconnect=8,rsize=1048576,wsize=1048576,hard,timeo=600
```





