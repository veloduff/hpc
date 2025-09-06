# GPU Performance Benchmark Suite

A comprehensive CUDA GPU benchmarking tool that tests performance across multiple categories and generates detailed reports.

## Features

- **Comprehensive Testing**: 22 benchmarks across 6 categories
- **Performance Analysis**: Memory bandwidth, compute performance, tensor cores, multi-GPU
- **Multiple Report Formats**: Terse summary, detailed web report, JSON data
- **Auto-Detection**: Automatically finds CUDA samples build directory
- **Easy to Use**: Single command execution

## Quick Start

```bash
# Run comprehensive benchmark suite
python3 run_gpu_benchmark.py

# View performance summary only
python3 performance_summary.py

# Generate web report from existing results
python3 web_report_generator.py gpu_benchmark_results_YYYYMMDD_HHMMSS.json
```

## Benchmark Categories

1. **Utilities** (3 tests)
   - deviceQuery: GPU device information
   - bandwidthTest: Memory bandwidth testing
   - topologyQuery: GPU topology analysis

2. **Performance** (5 tests)
   - matrixMul: Matrix multiplication performance
   - transpose: Memory transpose operations
   - reduction: Parallel reduction algorithms
   - scan: Prefix scan operations
   - alignedTypes: Memory alignment performance

3. **Tensor Cores** (4 tests)
   - cudaTensorCoreGemm: FP16 tensor performance
   - tf32TensorCoreGemm: TF32 tensor performance
   - bf16TensorCoreGemm: BF16 tensor performance
   - immaTensorCoreGemm: Integer tensor performance

4. **Libraries** (4 tests)
   - simpleCUBLAS: Basic CUBLAS operations
   - matrixMulCUBLAS: CUBLAS matrix multiplication
   - simpleCUFFT: FFT operations
   - conjugateGradient: Iterative solver

5. **Multi-GPU** (3 tests)
   - simpleMultiGPU: Multi-GPU computation
   - simpleP2P: Peer-to-peer communication
   - p2pBandwidthLatencyTest: P2P performance analysis

6. **Memory** (3 tests)
   - simpleZeroCopy: Zero-copy memory operations
   - UnifiedMemoryPerf: Unified memory performance
   - streamOrderedAllocation: Stream-ordered allocation

## Configuration

The suite automatically detects the CUDA samples build directory at:
```
~/cuda-samples-12.8/build/Samples
```

To use a different location, modify the `build_dir` parameter in `gpu_benchmark_suite.py`.

## Output Files

- `gpu_benchmark_results_YYYYMMDD_HHMMSS.json`: Complete benchmark data
- `gpu_benchmark_report/index.html`: Interactive web report
- Console output: Terse performance summary

## Requirements

- CUDA Toolkit 12.8+
- Built CUDA samples
- Python 3.6+
- Web browser (for viewing reports)

## Example Output

```
============================================================
GPU PERFORMANCE SUMMARY
============================================================
System: 8x NVIDIA B200
Memory: 182GB per GPU | CUDA: 12.8

TEST RESULTS:
  ✓ 22/22 tests passed

MEMORY BANDWIDTH:
  Host→GPU: 55.2 GB/s
  GPU→Host: 56.8 GB/s
  GPU→GPU:  6067.0 GB/s

COMPUTE PERFORMANCE:
  FP32:     4569.93 GFLOPS
  FP16:     107.03 TFLOPS
  TF32:     45.52 TFLOPS
  BF16:     185.86 TFLOPS

MULTI-GPU:
  P2P:      596.73 GB/s
  Topology: Full mesh (all GPUs connected)

PERFORMANCE RATING:
  Memory:   EXCELLENT
  Compute:  EXCELLENT
  Multi-GPU: EXCELLENT
============================================================
```