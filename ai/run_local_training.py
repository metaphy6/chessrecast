# ChessRecast AI POC - Local Training (No Docker)
# Run this if you have Python 3.10+ and PyTorch installed locally

import subprocess
import sys
from pathlib import Path

def check_dependencies():
    """Check if required packages are installed"""
    required = ['torch', 'chess', 'numpy', 'tqdm']
    missing = []
    
    for package in required:
        try:
            __import__(package)
        except ImportError:
            missing.append(package)
    
    if missing:
        print(f"❌ Missing packages: {', '.join(missing)}")
        print("\nInstall with:")
        print(f"pip install torch chess numpy tqdm")
        return False
    
    print("✅ All dependencies installed")
    return True

def main():
    print("=" * 60)
    print("ChessRecast AI POC - Local Training")
    print("=" * 60)
    
    # Check dependencies
    if not check_dependencies():
        return
    
    # Check if we're in the right directory
    trainer_dir = Path(__file__).parent / 'trainer'
    if not trainer_dir.exists():
        print(f"❌ Trainer directory not found: {trainer_dir}")
        return
    
    # Update checkpoint path for local execution
    train_file = trainer_dir / 'train.py'
    if train_file.exists():
        content = train_file.read_text()
        # Replace Docker path with local path
        content = content.replace(
            "checkpoint_dir = Path('/workspace/checkpoints')",
            "checkpoint_dir = Path(__file__).parent / 'checkpoints'"
        )
        train_file.write_text(content)
    
    # Same for export script
    export_file = trainer_dir / 'export_tflite.py'
    if export_file.exists():
        content = export_file.read_text()
        content = content.replace(
            "checkpoint_dir = Path('/workspace/checkpoints')",
            "checkpoint_dir = Path(__file__).parent / 'checkpoints'"
        )
        content = content.replace(
            "output_path = Path('/workspace/checkpoints/chess_classic_poc.tflite')",
            "output_path = Path(__file__).parent / 'checkpoints' / 'chess_classic_poc.tflite'"
        )
        export_file.write_text(content)
    
    print("\n✅ Training setup complete")
    print("\nStarting training...")
    print("This will take 2-3 hours. You can stop anytime with Ctrl+C")
    print("Checkpoints will be saved in ai/trainer/checkpoints/")
    print("\n" + "=" * 60 + "\n")
    
    # Run training
    try:
        subprocess.run([sys.executable, str(train_file)], cwd=str(trainer_dir))
    except KeyboardInterrupt:
        print("\n\n⚠️ Training interrupted by user")
        print("Checkpoints have been saved. You can resume later.")

if __name__ == "__main__":
    main()
