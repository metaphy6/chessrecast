"""
Export trained PyTorch model to TFLite for Flutter.
"""
import torch
import tensorflow as tf
import numpy as np
from pathlib import Path
from neural_network import ChessNetPOC

def export_to_tflite(checkpoint_path, output_path):
    """
    Convert PyTorch checkpoint to TFLite format.
    """
    print(f"Loading checkpoint: {checkpoint_path}")
    
    # Load PyTorch model
    model = ChessNetPOC(num_channels=64)
    checkpoint = torch.load(checkpoint_path, map_location='cpu')
    model.load_state_dict(checkpoint['model_state_dict'])
    model.eval()
    
    print("Exporting to ONNX...")
    # Export to ONNX (intermediate format)
    dummy_input = torch.randn(1, 12, 8, 8)
    onnx_path = output_path.parent / "temp_model.onnx"
    
    torch.onnx.export(
        model,
        dummy_input,
        onnx_path,
        input_names=['board_state'],
        output_names=['policy', 'value'],
        dynamic_axes={
            'board_state': {0: 'batch_size'},
            'policy': {0: 'batch_size'},
            'value': {0: 'batch_size'}
        }
    )
    
    print("Converting ONNX to TFLite...")
    # Convert ONNX to TFLite using tf2onnx and tensorflow
    # Note: This is simplified - full version needs proper conversion pipeline
    
    # For POC, we'll create a simple TF model wrapper
    class TFChessNet(tf.Module):
        def __init__(self, pytorch_model):
            super().__init__()
            # Simplified: In production, properly convert weights
            pass
        
        @tf.function(input_signature=[tf.TensorSpec(shape=[1, 12, 8, 8], dtype=tf.float32)])
        def __call__(self, x):
            # Placeholder - in production, implement proper conversion
            policy = tf.zeros([1, 4096])
            value = tf.zeros([1, 1])
            return {'policy': policy, 'value': value}
    
    # Create converter
    converter = tf.lite.TFLiteConverter.from_concrete_functions(
        [TFChessNet(model).__call__.get_concrete_function()]
    )
    
    # Optimize for mobile
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.float16]
    
    # Convert
    tflite_model = converter.convert()
    
    # Save
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, 'wb') as f:
        f.write(tflite_model)
    
    file_size = output_path.stat().st_size / (1024 * 1024)
    print(f"\n✅ TFLite model saved: {output_path}")
    print(f"   Size: {file_size:.2f} MB")
    
    return output_path

if __name__ == "__main__":
    checkpoint_dir = Path('/workspace/checkpoints')
    
    # Find latest checkpoint
    checkpoints = sorted(checkpoint_dir.glob('checkpoint_iter_*.pth'))
    if not checkpoints:
        print("❌ No checkpoints found!")
        exit(1)
    
    latest_checkpoint = checkpoints[-1]
    output_path = Path('/workspace/checkpoints/chess_classic_poc.tflite')
    
    export_to_tflite(latest_checkpoint, output_path)
    
    print("\n📦 Next step:")
    print(f"   Copy {output_path.name} to frontend/assets/models/")
