#!/usr/bin/env python3
"""
GPU/CPU monitoring utilities for training.

Provides real-time GPU utilization tracking using nvidia-smi,
with CPU fallback when no GPU is available.
"""

import os
import subprocess
import threading
import time


def get_gpu_utilization():
    """
    Query current GPU utilization percentage using nvidia-smi.
    
    Returns:
        int: GPU utilization percentage (0-100), or -1 if query fails
    """
    try:
        result = subprocess.run(
            ['nvidia-smi', '--query-gpu=utilization.gpu', '--format=csv,noheader,nounits'],
            capture_output=True, text=True, timeout=1)
        return int(result.stdout.strip())
    except Exception:
        return -1


def _get_gpu_memory():
    """Query GPU memory used/total in MB."""
    try:
        result = subprocess.run(
            ['nvidia-smi', '--query-gpu=memory.used,memory.total', '--format=csv,noheader,nounits'],
            capture_output=True, text=True, timeout=1)
        parts = result.stdout.strip().split(',')
        return int(parts[0].strip()), int(parts[1].strip())
    except Exception:
        return -1, -1


def _get_cpu_percent():
    """Get CPU utilization percentage (cross-platform)."""
    try:
        # Try /proc/stat (Linux/Docker) — non-blocking, fast
        with open('/proc/stat', 'r') as f:
            line = f.readline()
        fields = line.split()
        idle = int(fields[4])
        total = sum(int(x) for x in fields[1:])
        # We need two samples to compute %, so store last reading
        if not hasattr(_get_cpu_percent, '_prev'):
            _get_cpu_percent._prev = (idle, total)
            return -1
        prev_idle, prev_total = _get_cpu_percent._prev
        _get_cpu_percent._prev = (idle, total)
        d_idle = idle - prev_idle
        d_total = total - prev_total
        if d_total == 0:
            return 0
        return int((1 - d_idle / d_total) * 100)
    except Exception:
        return -1


class GPUMonitor:
    """
    Background GPU/CPU monitoring thread.
    
    Continuously polls GPU utilization and maintains the last known value.
    Falls back to CPU monitoring when no GPU is available.
    
    Usage:
        monitor = GPUMonitor()
        monitor.start()
        # ... do training ...
        util = monitor.get_utilization()
        info = monitor.get_status_str()
        monitor.stop()
    """
    
    def __init__(self):
        self.running = False
        self.thread = None
        self.last_util = 0
        self.last_mem_used = 0
        self.last_mem_total = 0
        self.last_cpu = 0
        self.has_gpu = get_gpu_utilization() >= 0

    def start(self):
        """Start the background monitoring thread."""
        self.running = True
        self.thread = threading.Thread(target=self._monitor, daemon=True)
        self.thread.start()

    def stop(self):
        """Stop the background monitoring thread."""
        self.running = False
        if self.thread:
            self.thread.join(timeout=2)

    def _monitor(self):
        """Internal monitoring loop (runs in background thread)."""
        while self.running:
            if self.has_gpu:
                util = get_gpu_utilization()
                if util >= 0:
                    self.last_util = util
                mem_used, mem_total = _get_gpu_memory()
                if mem_used >= 0:
                    self.last_mem_used = mem_used
                    self.last_mem_total = mem_total
            cpu = _get_cpu_percent()
            if cpu >= 0:
                self.last_cpu = cpu
            time.sleep(2)

    def get_utilization(self):
        """
        Get the most recently measured GPU utilization.
        
        Returns:
            int: GPU utilization percentage (0-100)
        """
        return self.last_util

    def get_status_str(self):
        """
        Get a compact status string for logging.
        
        Returns:
            str: e.g. "GPU:87% 4.2/12.0GB  CPU:34%" or "CPU:45%" (no GPU)
        """
        parts = []
        if self.has_gpu:
            parts.append(f"GPU:{self.last_util}%")
            if self.last_mem_total > 0:
                used_gb = self.last_mem_used / 1024
                total_gb = self.last_mem_total / 1024
                parts.append(f"{used_gb:.1f}/{total_gb:.0f}GB")
        if self.last_cpu >= 0:
            parts.append(f"CPU:{self.last_cpu}%")
        return "  ".join(parts) if parts else ""
