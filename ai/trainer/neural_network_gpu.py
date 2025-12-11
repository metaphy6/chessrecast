"""
GPU-Optimized neural network with performance enhancements:
- In-place ReLU operations (memory efficient)
- bias=False before BatchNorm (redundant bias)
- Proper nn.Module organization
"""
import torch
import torch.nn as nn

class ResidualBlock(nn.Module):
    """Optimized residual block"""
    def __init__(self, num_channels):
        super(ResidualBlock, self).__init__()
        # No bias before BatchNorm (bias is redundant)
        self.conv1 = nn.Conv2d(num_channels, num_channels, 3, padding=1, bias=False)
        self.bn1 = nn.BatchNorm2d(num_channels)
        self.conv2 = nn.Conv2d(num_channels, num_channels, 3, padding=1, bias=False)
        self.bn2 = nn.BatchNorm2d(num_channels)
        self.relu = nn.ReLU(inplace=True)  # In-place for memory efficiency
    
    def forward(self, x):
        residual = x
        out = self.relu(self.bn1(self.conv1(x)))
        out = self.bn2(self.conv2(out))
        out += residual
        out = self.relu(out)
        return out

class ChessNetPOC(nn.Module):
    """
    GPU-optimized AlphaZero-style network.
    
    Architecture:
    - Input: 8x8x12 board (6 piece types × 2 colors)
    - Backbone: Convolutional layers with residual blocks
    - Outputs: Policy (4096 possible moves) + Value (-1 to +1)
    
    Optimizations:
    - bias=False before BatchNorm
    - In-place ReLU operations
    - Efficient memory layout
    """
    
    def __init__(self, num_channels=64, num_res_blocks=2):
        super(ChessNetPOC, self).__init__()
        
        # Initial convolution (no bias before BatchNorm)
        self.conv_initial = nn.Conv2d(12, num_channels, 3, padding=1, bias=False)
        self.bn_initial = nn.BatchNorm2d(num_channels)
        self.relu = nn.ReLU(inplace=True)
        
        # Residual blocks
        self.res_blocks = nn.ModuleList([
            ResidualBlock(num_channels) for _ in range(num_res_blocks)
        ])
        
        # Policy head
        self.policy_conv = nn.Conv2d(num_channels, 32, 1, bias=False)
        self.policy_bn = nn.BatchNorm2d(32)
        self.policy_fc = nn.Linear(32 * 8 * 8, 4096)
        
        # Value head
        self.value_conv = nn.Conv2d(num_channels, 32, 1, bias=False)
        self.value_bn = nn.BatchNorm2d(32)
        self.value_fc1 = nn.Linear(32 * 8 * 8, 256)
        self.value_fc2 = nn.Linear(256, 1)
    
    def forward(self, x):
        """
        Forward pass.
        x: (batch, 12, 8, 8) board tensor
        Returns: (policy, value)
          - policy: (batch, 4096) move logits
          - value: (batch, 1) position evaluation [-1, +1]
        """
        # Initial convolution
        x = self.relu(self.bn_initial(self.conv_initial(x)))
        
        # Residual blocks
        for block in self.res_blocks:
            x = block(x)
        
        # Policy head (move prediction)
        policy = self.relu(self.policy_bn(self.policy_conv(x)))
        policy = policy.view(policy.size(0), -1)
        policy = self.policy_fc(policy)
        
        # Value head (position evaluation)
        value = self.relu(self.value_bn(self.value_conv(x)))
        value = value.view(value.size(0), -1)
        value = self.relu(self.value_fc1(value))
        value = torch.tanh(self.value_fc2(value))
        
        return policy, value

def count_parameters(model):
    """Count trainable parameters"""
    return sum(p.numel() for p in model.parameters() if p.requires_grad)

if __name__ == "__main__":
    # Test the network
    print("Testing ChessNetPOC...")
    model = ChessNetPOC(num_channels=64)
    print(f"Parameters: {count_parameters(model):,}")
    
    # Test forward pass
    x = torch.randn(2, 12, 8, 8)  # Batch of 2
    policy, value = model(x)
    print(f"Policy shape: {policy.shape}")  # (2, 4096)
    print(f"Value shape: {value.shape}")    # (2, 1)
    print("✓ Network test passed!")
