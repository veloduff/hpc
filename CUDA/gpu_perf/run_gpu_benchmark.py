#!/usr/bin/env python3

"""
CUDA GPU Comprehensive Benchmark Suite

This tool runs comprehensive GPU benchmarks and generates detailed performance reports.
"""

import os
import sys
from gpu_benchmark_suite import GPUBenchmarkSuite
from performance_summary import print_performance_summary
from web_report_generator import generate_web_report

def main():
    print("CUDA GPU Comprehensive Benchmark Suite")
    print("=" * 60)
    print("This tool will:")
    print("1. Run comprehensive GPU benchmarks")
    print("2. Generate detailed performance analysis")
    print("3. Create interactive web report")
    print("4. Provide reusable benchmarking framework")
    print("=" * 60)
    print()
    
    print("Starting benchmark suite...")
    
    # Run benchmarks
    suite = GPUBenchmarkSuite()
    results = suite.run_all_benchmarks()
    
    # Save results
    results_file = suite.save_results()
    print()
    
    # Generate performance summary
    print("Generating performance summary...")
    print_performance_summary(results_file)
    print()
    
    # Generate web report
    print("Generating web report...")
    html_file = generate_web_report(results_file)
    print()
    
    print("Benchmark Suite Completed!")
    print("=" * 60)
    print(f"Results file: {results_file}")
    print(f"Web report: {html_file}")
    print(f"Report directory: gpu_benchmark_report")
    print()
    
    # Try to open the report in browser
    try:
        import webbrowser
        full_path = os.path.abspath(html_file)
        print(f"Opening report in browser: file://{full_path}")
        webbrowser.open(f"file://{full_path}")
    except:
        print(f"Open this file in your browser: {os.path.abspath(html_file)}")

if __name__ == "__main__":
    main()