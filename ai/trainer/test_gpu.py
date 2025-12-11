"""
Quick GPU detection test.
Run this first to verify GPU is accessible in Docker.
"""
import torch
import sys

print("=" * 60)
print("GPU Detection Test")
print("=" * 60)

print(f"\nPyTorch version: {torch.__version__}")
print(f"CUDA available: {torch.cuda.is_available()}")

if torch.cuda.is_available():
    print(f"CUDA version: {torch.version.cuda}")
    print(f"cuDNN version: {torch.backends.cudnn.version()}")
    print(f"\nGPU Device: {torch.cuda.get_device_name(0)}")
    props = torch.cuda.get_device_properties(0)
    print(f"Compute Capability: {props.major}.{props.minor}")
    print(f"Total VRAM: {props.total_memory / 1e9:.1f} GB")
    print(f"Multi-Processor Count: {props.multi_processor_count}")
    
    # Quick compute test
    print("\nPerforming quick compute test...")
    x = torch.randn(1000, 1000, device='cuda')
    y = torch.randn(1000, 1000, device='cuda')
    z = torch.matmul(x, y)
    print("✓ Matrix multiplication successful on GPU")
    
    print("\n" + "=" * 60)
    print("✅ GPU is ready for training!")
    print("=" * 60)
else:
    print("\n" + "=" * 60)
    print("❌ GPU NOT DETECTED!")
    print("=" * 60)
    print("\nPlease check:")
    print("  1. Docker Desktop has GPU support enabled")
    print("  2. NVIDIA Container Toolkit is installed")
    print("  3. docker-compose has 'runtime: nvidia' configured")
    sys.exit(1)
