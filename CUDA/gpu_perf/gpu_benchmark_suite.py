#!/usr/bin/env python3

import os
import sys
import json
import time
import subprocess
from datetime import datetime
from pathlib import Path
import re

class GPUBenchmarkSuite:
    def __init__(self, build_dir=None):
        if build_dir is None:
            build_dir = os.path.expanduser("~/cuda-samples-12.8/build/Samples")
        self.build_dir = Path(build_dir)
        
        # Check if CUDA samples directory exists
        if not self.build_dir.exists():
            print(f"ERROR: CUDA samples directory not found: {self.build_dir}")
            print("Please build CUDA samples first:")
            print("  cd ~/cuda-samples-12.8 && mkdir -p build && cd build")
            print("  cmake .. && make -j$(nproc)")
            sys.exit(1)
        
        self.results = {
            "system_info": {},
            "device_info": {},
            "benchmarks": {},
            "timestamp": datetime.now().isoformat(),
            "summary": {}
        }
        
        # Define benchmark categories and their executables
        self.benchmark_categories = {
            "utilities": {
                "deviceQuery": "1_Utilities/deviceQuery/deviceQuery",
                "bandwidthTest": "1_Utilities/bandwidthTest/bandwidthTest",
                "topologyQuery": "1_Utilities/topologyQuery/topologyQuery"
            },
            "performance": {
                "matrixMul": "0_Introduction/matrixMul/matrixMul",
                "transpose": "6_Performance/transpose/transpose",
                "reduction": "2_Concepts_and_Techniques/reduction/reduction",
                "scan": "2_Concepts_and_Techniques/scan/scan",
                "alignedTypes": "6_Performance/alignedTypes/alignedTypes"
            },
            "tensor_cores": {
                "cudaTensorCoreGemm": "3_CUDA_Features/cudaTensorCoreGemm/cudaTensorCoreGemm",
                "tf32TensorCoreGemm": "3_CUDA_Features/tf32TensorCoreGemm/tf32TensorCoreGemm",
                "bf16TensorCoreGemm": "3_CUDA_Features/bf16TensorCoreGemm/bf16TensorCoreGemm",
                "immaTensorCoreGemm": "3_CUDA_Features/immaTensorCoreGemm/immaTensorCoreGemm"
            },
            "libraries": {
                "simpleCUBLAS": "4_CUDA_Libraries/simpleCUBLAS/simpleCUBLAS",
                "matrixMulCUBLAS": "4_CUDA_Libraries/matrixMulCUBLAS/matrixMulCUBLAS",
                "simpleCUFFT": "4_CUDA_Libraries/simpleCUFFT/simpleCUFFT",
                "conjugateGradient": "4_CUDA_Libraries/conjugateGradient/conjugateGradient"
            },
            "multi_gpu": {
                "simpleMultiGPU": "0_Introduction/simpleMultiGPU/simpleMultiGPU",
                "simpleP2P": "0_Introduction/simpleP2P/simpleP2P",
                "p2pBandwidthLatencyTest": "5_Domain_Specific/p2pBandwidthLatencyTest/p2pBandwidthLatencyTest"
            },
            "memory": {
                "simpleZeroCopy": "0_Introduction/simpleZeroCopy/simpleZeroCopy",
                "UnifiedMemoryPerf": "6_Performance/UnifiedMemoryPerf/UnifiedMemoryPerf",
                "streamOrderedAllocation": "2_Concepts_and_Techniques/streamOrderedAllocation/streamOrderedAllocation"
            }
        }

    def run_command(self, cmd, cwd=None, timeout=300):
        """Run a command and capture output with timeout"""
        try:
            start_time = time.time()
            result = subprocess.run(
                cmd, shell=True, cwd=cwd, capture_output=True, 
                text=True, timeout=timeout
            )
            end_time = time.time()
            
            return {
                "success": result.returncode == 0,
                "stdout": result.stdout,
                "stderr": result.stderr,
                "execution_time": end_time - start_time,
                "return_code": result.returncode
            }
        except subprocess.TimeoutExpired:
            return {
                "success": False,
                "stdout": "",
                "stderr": f"Command timed out after {timeout} seconds",
                "execution_time": timeout,
                "return_code": -1
            }
        except Exception as e:
            return {
                "success": False,
                "stdout": "",
                "stderr": str(e),
                "execution_time": 0,
                "return_code": -1
            }

    def get_system_info(self):
        """Gather system information"""
        print("Gathering system information...")
        
        # Get CPU info
        cpu_info = self.run_command("lscpu")
        self.results["system_info"]["cpu"] = cpu_info["stdout"] if cpu_info["success"] else "N/A"
        
        # Get memory info
        mem_info = self.run_command("free -h")
        self.results["system_info"]["memory"] = mem_info["stdout"] if mem_info["success"] else "N/A"
        
        # Get CUDA version
        cuda_info = self.run_command("nvcc --version")
        self.results["system_info"]["cuda"] = cuda_info["stdout"] if cuda_info["success"] else "N/A"
        
        # Get driver version
        driver_info = self.run_command("nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits")
        self.results["system_info"]["driver"] = driver_info["stdout"].strip() if driver_info["success"] else "N/A"

    def get_device_info(self):
        """Get detailed GPU device information"""
        print("Gathering GPU device information...")
        
        device_query_path = self.build_dir / "1_Utilities/deviceQuery/deviceQuery"
        if device_query_path.exists():
            result = self.run_command(str(device_query_path))
            if result["success"]:
                self.results["device_info"]["raw_output"] = result["stdout"]
                self.parse_device_info(result["stdout"])
            else:
                self.results["device_info"]["error"] = result["stderr"]
                self.results["device_info"]["devices"] = []
                self.results["device_info"]["device_count"] = 0
        else:
            # Fallback: use nvidia-smi to get device count
            smi_result = self.run_command("nvidia-smi -L")
            if smi_result["success"]:
                device_count = len([line for line in smi_result["stdout"].split('\n') if 'GPU' in line and ':' in line])
                self.results["device_info"]["devices"] = [{"id": i, "name": "Unknown GPU"} for i in range(device_count)]
                self.results["device_info"]["device_count"] = device_count
            else:
                self.results["device_info"]["devices"] = []
                self.results["device_info"]["device_count"] = 0

    def parse_device_info(self, output):
        """Parse deviceQuery output to extract structured information"""
        devices = []
        current_device = {}
        
        for line in output.split('\n'):
            line = line.strip()
            if line.startswith('Device ') and '"' in line:
                if current_device:
                    devices.append(current_device)
                device_match = re.search(r'Device (\d+): "([^"]+)"', line)
                if device_match:
                    current_device = {
                        "id": int(device_match.group(1)),
                        "name": device_match.group(2)
                    }
            elif ':' in line and current_device and not line.startswith('>'):
                if ('deviceQuery' in line or 'CUDA Driver' in line or 
                    'Result =' in line or line.startswith('Detected')):
                    continue
                key, value = line.split(':', 1)
                key = key.strip().replace(' ', '_').lower()
                value = value.strip()
                if key and value:
                    current_device[key] = value
        
        if current_device:
            devices.append(current_device)
        
        self.results["device_info"]["devices"] = devices
        self.results["device_info"]["device_count"] = len(devices)
        
        # Ensure we have at least basic device info
        if len(devices) == 0:
            # Fallback: use nvidia-smi
            smi_result = self.run_command("nvidia-smi -L")
            if smi_result["success"]:
                device_count = len([line for line in smi_result["stdout"].split('\n') if 'GPU' in line and ':' in line])
                self.results["device_info"]["devices"] = [{"id": i, "name": "Unknown GPU"} for i in range(device_count)]
                self.results["device_info"]["device_count"] = device_count

    def run_benchmark(self, category, name, executable_path):
        """Run a single benchmark"""
        full_path = self.build_dir / executable_path
        
        if not full_path.exists():
            return {
                "status": "skipped",
                "reason": "Executable not found",
                "path": str(full_path)
            }
        
        print(f"Running {name}...", end="", flush=True)
        
        # Run the benchmark multiple times for better statistics
        runs = []
        for i in range(3):
            result = self.run_command(str(full_path), timeout=600)
            runs.append(result)
            if not result["success"]:
                break
        
        # Calculate statistics
        if runs and runs[0]["success"]:
            execution_times = [run["execution_time"] for run in runs if run["success"]]
            avg_time = sum(execution_times) / len(execution_times)
            print(" done")
            
            benchmark_result = {
                "status": "completed",
                "runs": len(execution_times),
                "avg_time": avg_time,
                "min_time": min(execution_times),
                "max_time": max(execution_times),
                "stdout": runs[0]["stdout"],
                "stderr": runs[0]["stderr"]
            }
            
            # Extract performance metrics from output
            benchmark_result.update(self.extract_performance_metrics(runs[0]["stdout"], name))
        else:
            print("FAILED")
            benchmark_result = {
                "status": "failed",
                "error": runs[0]["stderr"] if runs else "Unknown error",
                "stdout": runs[0]["stdout"] if runs else "",
                "stderr": runs[0]["stderr"] if runs else ""
            }
        
        return benchmark_result

    def extract_performance_metrics(self, output, benchmark_name):
        """Extract performance metrics from benchmark output"""
        metrics = {}
        
        # Common patterns for different benchmarks
        patterns = {
            "bandwidth": r"(\d+\.?\d*)\s*(GB/s|MB/s)",
            "gflops": r"(\d+\.?\d*)\s*(GFLOPS|GFlop/s)",
            "throughput": r"(\d+\.?\d*)\s*(elements/sec|ops/sec)",
            "time": r"(\d+\.?\d*)\s*(ms|seconds?)",
            "performance": r"Performance:\s*(\d+\.?\d*)",
            "speedup": r"Speedup:\s*(\d+\.?\d*)"
        }
        
        for metric_name, pattern in patterns.items():
            matches = re.findall(pattern, output, re.IGNORECASE)
            if matches:
                metrics[metric_name] = matches
        
        return metrics

    def run_all_benchmarks(self):
        """Run all benchmarks in all categories"""
        print("Starting comprehensive GPU benchmark suite...")
        print("Note: Each test is run 3 times for statistical accuracy\n")
        
        # Gather system information
        self.get_system_info()
        self.get_device_info()
        
        # Run benchmarks by category
        for category, benchmarks in self.benchmark_categories.items():
            print(f"=== Running {category.upper()} benchmarks ===")
            self.results["benchmarks"][category] = {}
            
            for name, executable_path in benchmarks.items():
                result = self.run_benchmark(category, name, executable_path)
                self.results["benchmarks"][category][name] = result
            
            print()
        
        # Generate summary
        self.generate_summary()
        
        return self.results

    def generate_summary(self):
        """Generate benchmark summary statistics"""
        total_benchmarks = 0
        completed = 0
        failed = 0
        skipped = 0
        
        categories = {}
        
        for category, benchmarks in self.results["benchmarks"].items():
            cat_completed = cat_failed = cat_skipped = 0
            
            for name, result in benchmarks.items():
                total_benchmarks += 1
                if result["status"] == "completed":
                    completed += 1
                    cat_completed += 1
                elif result["status"] == "failed":
                    failed += 1
                    cat_failed += 1
                else:
                    skipped += 1
                    cat_skipped += 1
            
            categories[category] = {
                "completed": cat_completed,
                "failed": cat_failed,
                "skipped": cat_skipped
            }
        
        self.results["summary"] = {
            "total_benchmarks": total_benchmarks,
            "completed": completed,
            "failed": failed,
            "skipped": skipped,
            "categories": categories
        }

    def save_results(self, filename=None):
        """Save results to JSON file"""
        if filename is None:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"gpu_benchmark_results_{timestamp}.json"
        
        with open(filename, 'w') as f:
            json.dump(self.results, f, indent=2)
        
        print(f"Results saved to {filename}")
        return filename

if __name__ == "__main__":
    suite = GPUBenchmarkSuite()
    results = suite.run_all_benchmarks()
    filename = suite.save_results()