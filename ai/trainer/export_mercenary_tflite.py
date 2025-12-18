"""
Export Mercenary 1800 ELO model to TFLite for Flutter integration
"""
import torch
import tensorflow as tf
import numpy as np
from pathlib import Path
import sys

# Add trainer directory to path
sys.path.insert(0, str(Path(__file__).parent))

from neural_network_gpu import ChessNetPOC


class TorchToTFLiteConverter:
    """Convert PyTorch ChessNet to TFLite"""
    
    def __init__(self, torch_model, device='cuda'):
        self.torch_model = torch_model.to(device)
        self.torch_model.eval()
        self.device = device
    
    def convert(self, output_path):
        """Convert and save as TFLite"""
        print("🔄 Converting PyTorch model to TFLite...")
        
        # Create a TensorFlow model that wraps the PyTorch model
        class TFWrapper(tf.Module):
            def __init__(self, torch_model, device):
                super().__init__()
                self.torch_model = torch_model
                self.device = device
            
            @tf.function(input_signature=[
                tf.TensorSpec(shape=[1, 12, 8, 8], dtype=tf.float32, name='input')
            ])
            def __call__(self, x):
                # Convert TF tensor to PyTorch
                x_np = x.numpy()
                x_torch = torch.from_numpy(x_np).to(self.device)
                
                # Run inference
                with torch.no_grad():
                    policy, value = self.torch_model(x_torch)
                
                # Convert back to TF
                policy_np = policy.cpu().numpy()
                value_np = value.cpu().numpy()
                
                return {
                    'policy': tf.convert_to_tensor(policy_np, dtype=tf.float32),
                    'value': tf.convert_to_tensor(value_np, dtype=tf.float32)
                }
        
        # Create wrapper
        tf_model = TFWrapper(self.torch_model, self.device)
        
        # Convert to TFLite
        converter = tf.lite.TFLiteConverter.from_concrete_functions([
            tf_model.__call__.get_concrete_function()
        ])
        
        # Optimization
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.target_spec.supported_ops = [
            tf.lite.OpsSet.TFLITE_BUILTINS,
            tf.lite.OpsSet.SELECT_TF_OPS
        ]
        
        tflite_model = converter.convert()
        
        # Save
        with open(output_path, 'wb') as f:
            f.write(tflite_model)
        
        print(f"✓ TFLite model saved: {output_path}")
        print(f"   Size: {len(tflite_model) / 1024 / 1024:.2f} MB")
        
        return output_path


def export_mercenary_model():
    """Export the trained Mercenary model"""
    print("=" * 80)
    print("EXPORT MERCENARY 1800 MODEL TO TFLITE")
    print("=" * 80)
    
    # Paths
    checkpoint_dir = Path('/workspace/checkpoints/mercenary_1800')
    model_path = checkpoint_dir / 'mercenary_1800_final.pth'
    output_path = Path('/workspace/models/mercenary_1800.tflite')
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    if not model_path.exists():
        print(f"\n❌ Model not found: {model_path}")
        print("   Run train_mercenary_1800.py first!")
        sys.exit(1)
    
    device = 'cuda' if torch.cuda.is_available() else 'cpu'
    print(f"\n📦 Loading model from: {model_path}")
    print(f"   Device: {device}")
    
    # Load model
    model = ChessNetPOC(num_channels=128, num_res_blocks=10).to(device)
    model.load_state_dict(torch.load(model_path, map_location=device))
    model.eval()
    print("   ✓ Model loaded")
    
    # Test inference
    print("\n🧪 Testing inference...")
    test_input = torch.randn(1, 12, 8, 8).to(device)
    with torch.no_grad():
        policy, value = model(test_input)
    print(f"   Policy shape: {policy.shape}")
    print(f"   Value shape: {value.shape}")
    print("   ✓ Inference test passed")
    
    # Convert to TFLite
    print(f"\n🔄 Converting to TFLite...")
    converter = TorchToTFLiteConverter(model, device=device)
    converter.convert(output_path)
    
    print(f"\n✓ Export complete!")
    print(f"\n📋 Next steps:")
    print(f"   1. Copy {output_path} to Flutter assets:")
    print(f"      cp {output_path} frontend/assets/models/")
    print(f"   2. Update pubspec.yaml to include the model")
    print(f"   3. Integrate with AIService in Flutter")


if __name__ == "__main__":
    export_mercenary_model()
