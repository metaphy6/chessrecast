#!/usr/bin/env python3
"""
GPU monitoring utilities for training.

Provides real-time GPU utilization tracking using nvidia-smi.
"""

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


class GPUMonitor:
    """
    Background GPU monitoring thread.
    
    Continuously polls GPU utilization and maintains the last known value.
    Useful for tracking GPU usage during training without blocking the main thread.
    
    Usage:
        monitor = GPUMonitor()
        monitor.start()
        # ... do training ...
        util = monitor.get_utilization()
        monitor.stop()
    """
    
    def __init__(self):
        self.running = False
        self.thread = None
        self.last_util = 0

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
            util = get_gpu_utilization()
            if util >= 0:
                self.last_util = util
            time.sleep(2)

    def get_utilization(self):
        """
        Get the most recently measured GPU utilization.
        
        Returns:
            int: GPU utilization percentage (0-100)
        """
        return self.last_util
