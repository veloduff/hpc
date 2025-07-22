#!/bin/bash
#
# Automated IOR Benchmark Script
# Based on the benchmarking.md documentation
#

set -e

# Configuration variables
IOR_BINARY="/usr/local/bin/ior"
TEST_DIR="/mnt/lustre/benchmarks"
OUTPUT_DIR="$HOME/ior_results"
PARTITION="batch01"
DEFAULT_NODES=4
DEFAULT_BLOCK_SIZE="10g"
DEFAULT_TRANSFER_SIZE="1M"
DEFAULT_ITERATIONS=3

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -n, --nodes NUM        Number of nodes (default: $DEFAULT_NODES)"
    echo "  -b, --block-size SIZE  Block size per task (default: $DEFAULT_BLOCK_SIZE)"
    echo "  -t, --transfer-size SIZE Transfer size (default: $DEFAULT_TRANSFER_SIZE)"
    echo "  -i, --iterations NUM   Number of iterations (default: $DEFAULT_ITERATIONS)"
    echo "  -p, --partition NAME   SLURM partition (default: $PARTITION)"
    echo "  -d, --test-dir PATH    Test directory (default: $TEST_DIR)"
    echo "  -a, --api API          I/O API (POSIX, MPIIO, HDF5) (default: MPIIO)"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                     # Run with defaults"
    echo "  $0 -n 8 -b 5g -a POSIX # Run on 8 nodes with 5GB blocks using POSIX"
}

# Parse command line arguments
NODES="$DEFAULT_NODES"
BLOCK_SIZE="$DEFAULT_BLOCK_SIZE"
TRANSFER_SIZE="$DEFAULT_TRANSFER_SIZE"
ITERATIONS="$DEFAULT_ITERATIONS"
API="MPIIO"

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--nodes)
            NODES="$2"
            shift 2
            ;;
        -b|--block-size)
            BLOCK_SIZE="$2"
            shift 2
            ;;
        -t|--transfer-size)
            TRANSFER_SIZE="$2"
            shift 2
            ;;
        -i|--iterations)
            ITERATIONS="$2"
            shift 2
            ;;
        -p|--partition)
            PARTITION="$2"
            shift 2
            ;;
        -d|--test-dir)
            TEST_DIR="$2"
            shift 2
            ;;
        -a|--api)
            API="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate API
case "$API" in
    POSIX|MPIIO|HDF5)
        ;;
    *)
        echo "Error: Invalid API '$API'. Must be POSIX, MPIIO, or HDF5"
        exit 1
        ;;
esac

# Generate timestamp for unique job names
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
JOB_NAME="ior_${API}_${NODES}n_${TIMESTAMP}"
BATCH_FILE="$OUTPUT_DIR/${JOB_NAME}.sbatch"
TEST_FILE="$TEST_DIR/testFile_${TIMESTAMP}"

echo "=== IOR Benchmark Configuration ==="
echo "Nodes: $NODES"
echo "Block size: $BLOCK_SIZE"
echo "Transfer size: $TRANSFER_SIZE"
echo "Iterations: $ITERATIONS"
echo "API: $API"
echo "Partition: $PARTITION"
echo "Test directory: $TEST_DIR"
echo "Test file: $TEST_FILE"
echo "Batch file: $BATCH_FILE"
echo ""

# Create SLURM batch script
cat > "$BATCH_FILE" << EOF
#!/bin/bash
#SBATCH -J $JOB_NAME
#SBATCH -o $OUTPUT_DIR/${JOB_NAME}.out
#SBATCH -e $OUTPUT_DIR/${JOB_NAME}.err
#SBATCH --exclusive
#SBATCH --nodes=$NODES
#SBATCH --ntasks-per-node=1

echo "=== IOR Benchmark Started at \$(date) ==="
echo "Configuration:"
echo "  Nodes: $NODES"
echo "  Block size: $BLOCK_SIZE"
echo "  Transfer size: $TRANSFER_SIZE"
echo "  Iterations: $ITERATIONS"
echo "  API: $API"
echo "  Test file: $TEST_FILE"
echo ""

# Load modules
module list

# Create test directory
mkdir -p $TEST_DIR

# Run IOR benchmark
EOF

# Add API-specific IOR command
if [[ "$API" == "POSIX" ]]; then
    cat >> "$BATCH_FILE" << EOF
srun --mpi=pmix_v5 $IOR_BINARY -o $TEST_FILE -b $BLOCK_SIZE -t $TRANSFER_SIZE -v -w -W -r -R -e -F -i $ITERATIONS --posix.odirect
EOF
else
    cat >> "$BATCH_FILE" << EOF
srun --mpi=pmix_v5 $IOR_BINARY -o $TEST_FILE -b $BLOCK_SIZE -t $TRANSFER_SIZE -v -w -W -r -R -e -F -i $ITERATIONS -a $API
EOF
fi

cat >> "$BATCH_FILE" << EOF

echo ""
echo "=== IOR Benchmark Completed at \$(date) ==="
EOF

# Make batch file executable
chmod +x "$BATCH_FILE"

# Submit job
echo "Submitting IOR benchmark job..."
JOB_ID=$(sbatch -p "$PARTITION" "$BATCH_FILE" | awk '{print $4}')

echo "Job submitted with ID: $JOB_ID"
echo "Monitor with: squeue -j $JOB_ID"
echo "Results will be in: $OUTPUT_DIR/${JOB_NAME}.out"
echo "Errors will be in: $OUTPUT_DIR/${JOB_NAME}.err"
echo ""
echo "To view results when complete:"
echo "  cat $OUTPUT_DIR/${JOB_NAME}.out"