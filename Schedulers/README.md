# Slurm Workload Manager

Slurm is an open-source workload manager designed for Linux clusters of all sizes. It provides three key functions:
1. Allocating access to resources to users for their work
2. Providing a framework for starting, executing, and monitoring work on allocated resources
3. Arbitrating contention for resources by managing a queue of pending work

## Common Commands

- `srun` - Run a parallel job on allocated resources
- `sbatch` - Submit a batch script for later execution
- `squeue` - View information about jobs in the scheduling queue
- `sinfo -s` - View summary information about the partitions
- `sinfo -l -N` - View detailed information about nodes
- `scontrol show node` - Display detailed configuration of nodes

## Environment Variables

Set partition (queue):
```sh
export SBATCH_PARTITION=batch01
```

## Troubleshooting MPI

### Check PMIx Version

If you encounter PMIx errors when running `srun`, it may be because the version is not specified. Use the `--mpi=list` argument to show available versions:

```
$ srun --mpi=list
MPI plugin types are...
	none
	cray_shasta
	pmi2
	pmix
specific pmix plugin versions available: pmix_v5
```

Then specify the correct version when running your job, for example:
```
srun --mpi=pmix_v5 your_application
```