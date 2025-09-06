#!/usr/bin/env python3

import json
import sys
import os
from datetime import datetime

def generate_web_report(json_file, output_dir="gpu_benchmark_report"):
    """Generate an interactive web report from benchmark results"""
    
    with open(json_file, 'r') as f:
        data = json.load(f)
    
    # Create output directory
    os.makedirs(output_dir, exist_ok=True)
    
    # Generate HTML report
    html_content = f"""
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>GPU Benchmark Report</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }}
        .container {{ max-width: 1200px; margin: 0 auto; }}
        .header {{ background: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }}
        .section {{ background: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }}
        .stats-grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin: 20px 0; }}
        .stat-card {{ background: #007acc; color: white; padding: 20px; border-radius: 8px; text-align: center; }}
        .stat-card h3 {{ margin: 0 0 10px 0; font-size: 2em; }}
        .device-grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 15px; }}
        .device-card {{ background: #f8f9fa; border: 1px solid #dee2e6; border-radius: 8px; padding: 15px; }}
        .benchmark-results {{ margin: 20px 0; }}
        .benchmark-item {{ background: #f8f9fa; padding: 15px; margin: 10px 0; border-radius: 8px; border-left: 4px solid #28a745; }}
        .benchmark-item.failed {{ border-left-color: #dc3545; }}
        .benchmark-item.skipped {{ border-left-color: #ffc107; }}
        .nav-tabs {{ display: flex; background: #e9ecef; border-radius: 8px; padding: 5px; margin-bottom: 20px; }}
        .tab-button {{ flex: 1; padding: 10px; border: none; background: transparent; cursor: pointer; border-radius: 4px; }}
        .tab-button.active {{ background: #007acc; color: white; }}
        .tab-content {{ display: none; }}
        .tab-content.active {{ display: block; }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 GPU Benchmark Report</h1>
            <p>Generated: {data['timestamp']}</p>
        </div>

        <nav class="nav-tabs">
            <button class="tab-button active" onclick="showTab('overview')">Overview</button>
            <button class="tab-button" onclick="showTab('system')">System Info</button>
            <button class="tab-button" onclick="showTab('devices')">GPU Devices</button>
            <button class="tab-button" onclick="showTab('results')">Detailed Results</button>
        </nav>

        <div id="overview" class="tab-content active">
            <div class="section">
                <h2>📊 Benchmark Overview</h2>
                
                <div class="stats-grid">
                    <div class="stat-card">
                        <h3>{data['device_info']['device_count']}</h3>
                        <p>GPU Devices</p>
                    </div>
                    <div class="stat-card">
                        <h3>{data['summary']['total_benchmarks']}</h3>
                        <p>Total Benchmarks</p>
                    </div>
                    <div class="stat-card">
                        <h3>{data['summary']['completed']}</h3>
                        <p>Completed</p>
                    </div>
                    <div class="stat-card">
                        <h3>{data['summary']['failed']}</h3>
                        <p>Failed</p>
                    </div>
                </div>
            </div>
        </div>

        <div id="system" class="tab-content">
            <div class="section">
                <h2>💻 System Information</h2>
                <pre>{data['system_info'].get('cpu', 'N/A')}</pre>
                <h3>Memory</h3>
                <pre>{data['system_info'].get('memory', 'N/A')}</pre>
                <h3>CUDA Version</h3>
                <pre>{data['system_info'].get('cuda', 'N/A')}</pre>
            </div>
        </div>

        <div id="devices" class="tab-content">
            <div class="section">
                <h2>🎮 GPU Devices</h2>
                <div class="device-grid">
"""
    
    # Add device cards
    for device in data['device_info']['devices']:
        html_content += f"""
                    <div class="device-card">
                        <h3>Device {device['id']}: {device['name']}</h3>
                        <p><strong>Memory:</strong> {device.get('total_amount_of_global_memory', 'N/A')}</p>
                        <p><strong>CUDA Cores:</strong> {device.get('(148)_multiprocessors,_(128)_cuda_cores/mp', 'N/A')}</p>
                        <p><strong>Clock Rate:</strong> {device.get('gpu_max_clock_rate', 'N/A')}</p>
                    </div>
"""
    
    html_content += """
                </div>
            </div>
        </div>

        <div id="results" class="tab-content">
            <div class="section">
                <h2>📈 Detailed Results</h2>
"""
    
    # Add benchmark results by category
    for category, benchmarks in data['benchmarks'].items():
        html_content += f"""
                <h3>{category.title()} Benchmarks</h3>
                <div class="benchmark-results">
"""
        for name, result in benchmarks.items():
            status_class = result['status']
            html_content += f"""
                    <div class="benchmark-item {status_class}">
                        <h4>{name}</h4>
                        <p><strong>Status:</strong> {result['status'].title()}</p>
"""
            if result['status'] == 'completed':
                html_content += f"""
                        <p><strong>Average Time:</strong> {result['avg_time']:.2f}s</p>
                        <p><strong>Runs:</strong> {result['runs']}</p>
"""
            elif result['status'] == 'failed':
                html_content += f"""
                        <p><strong>Error:</strong> {result.get('error', 'Unknown error')}</p>
"""
            html_content += """
                    </div>
"""
        html_content += """
                </div>
"""
    
    html_content += """
            </div>
        </div>
    </div>

    <script>
        function showTab(tabName) {
            // Hide all tab contents
            const contents = document.querySelectorAll('.tab-content');
            contents.forEach(content => content.classList.remove('active'));
            
            // Remove active class from all buttons
            const buttons = document.querySelectorAll('.tab-button');
            buttons.forEach(button => button.classList.remove('active'));
            
            // Show selected tab content
            document.getElementById(tabName).classList.add('active');
            
            // Add active class to clicked button
            event.target.classList.add('active');
        }
    </script>
</body>
</html>
"""
    
    # Write HTML file
    html_file = os.path.join(output_dir, "index.html")
    with open(html_file, 'w') as f:
        f.write(html_content)
    
    print(f"Web report generated: {html_file}")
    return html_file

if __name__ == "__main__":
    if len(sys.argv) > 1:
        json_file = sys.argv[1]
    else:
        # Find the most recent results file
        import glob
        files = glob.glob("gpu_benchmark_results_*.json")
        if files:
            json_file = max(files)
        else:
            print("No benchmark results found. Run gpu_benchmark_suite.py first.")
            sys.exit(1)
    
    generate_web_report(json_file)