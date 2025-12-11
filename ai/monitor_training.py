#!/usr/bin/env python3
"""
Live monitoring script for training progress.
Run this in a separate terminal while training is running.
"""
import subprocess
import time
import sys
from datetime import datetime

def get_container_id():
    """Get the running trainer container ID"""
    result = subprocess.run(
        ['docker', 'ps', '-q', '--filter', 'ancestor=docker-trainer:latest'],
        capture_output=True,
        text=True
    )
    container_id = result.stdout.strip()
    return container_id if container_id else None

def get_gpu_stats():
    """Get GPU utilization stats"""
    try:
        result = subprocess.run(
            ['nvidia-smi', '--query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu',
             '--format=csv,noheader,nounits'],
            capture_output=True,
            text=True,
            timeout=2
        )
        if result.returncode == 0:
            gpu_util, mem_used, mem_total, temp = result.stdout.strip().split(', ')
            return {
                'utilization': int(gpu_util),
                'memory_used': int(mem_used),
                'memory_total': int(mem_total),
                'temperature': int(temp)
            }
    except Exception:
        pass
    return None

def get_container_stats(container_id):
    """Get container CPU/memory stats"""
    try:
        result = subprocess.run(
            ['docker', 'stats', '--no-stream', '--format', 
             '{{.CPUPerc}},{{.MemUsage}}', container_id],
            capture_output=True,
            text=True,
            timeout=2
        )
        if result.returncode == 0:
            output = result.stdout.strip()
            if output:
                cpu_str, mem_str = output.split(',')
                cpu = float(cpu_str.rstrip('%'))
                return {'cpu': cpu, 'memory': mem_str}
    except Exception:
        pass
    return None

def main():
    print("=" * 70)
    print("ChessRecast AI Training Monitor")
    print("=" * 70)
    print("\nMonitoring training progress... (Ctrl+C to exit)\n")
    
    last_log_line = None
    
    try:
        while True:
            container_id = get_container_id()
            
            if not container_id:
                print(f"[{datetime.now().strftime('%H:%M:%S')}] ⏸️  No training container running")
                time.sleep(5)
                continue
            
            # Get stats
            gpu_stats = get_gpu_stats()
            container_stats = get_container_stats(container_id)
            
            # Get last log line
            try:
                result = subprocess.run(
                    ['docker', 'logs', '--tail', '1', container_id],
                    capture_output=True,
                    text=True,
                    timeout=2
                )
                current_log = result.stdout.strip() or result.stderr.strip()
                
                # Only print if new
                if current_log and current_log != last_log_line:
                    print(f"\n[{datetime.now().strftime('%H:%M:%S')}] {current_log}")
                    last_log_line = current_log
            except Exception:
                pass
            
            # Print stats on same line
            status_parts = []
            
            if container_stats:
                status_parts.append(f"CPU: {container_stats['cpu']:.0f}%")
                status_parts.append(f"RAM: {container_stats['memory']}")
            
            if gpu_stats:
                status_parts.append(f"GPU: {gpu_stats['utilization']}%")
                status_parts.append(f"VRAM: {gpu_stats['memory_used']}/{gpu_stats['memory_total']}MB")
                status_parts.append(f"Temp: {gpu_stats['temperature']}°C")
            
            if status_parts:
                status_line = f"\r[{datetime.now().strftime('%H:%M:%S')}] " + " | ".join(status_parts) + " " * 10
                print(status_line, end='', flush=True)
            
            time.sleep(2)
            
    except KeyboardInterrupt:
        print("\n\n✅ Monitoring stopped")
        sys.exit(0)

if __name__ == "__main__":
    main()
