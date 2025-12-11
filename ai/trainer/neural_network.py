"""
Lightweight neural network for POC.
Small size (~2M parameters, ~5MB file).
"""
import torch
import torch.nn as nn
import torch.nn.functional as F

class ChessNetPOC(nn.Module):
    """
    Simplified AlphaZero-style network.
    Input: 8x8x12 board tensor
    Outputs: Policy (move probabilities) + Value (position evaluation)
    """
    
    def __init__(self, num_channels=64):
        super().__init__()
        
        # Shared backbone (simplified ResNet)
        self.conv_initial = nn.Conv2d(12, num_channels, 3, padding=1)
        self.bn_initial = nn.BatchNorm2d(num_channels)
        
        # 2 residual blocks (simplified for POC)
        self.res1_conv1 = nn.Conv2d(num_channels, num_channels, 3, padding=1)
        self.res1_bn1 = nn.BatchNorm2d(num_channels)
        self.res1_conv2 = nn.Conv2d(num_channels, num_channels, 3, padding=1)
        self.res1_bn2 = nn.BatchNorm2d(num_channels)
        
        self.res2_conv1 = nn.Conv2d(num_channels, num_channels, 3, padding=1)
        self.res2_bn1 = nn.BatchNorm2d(num_channels)
        self.res2_conv2 = nn.Conv2d(num_channels, num_channels, 3, padding=1)
        self.res2_bn2 = nn.BatchNorm2d(num_channels)
        
        # Policy head (move prediction)
        self.policy_conv = nn.Conv2d(num_channels, 32, 1)
        self.policy_bn = nn.BatchNorm2d(32)
        self.policy_fc = nn.Linear(32 * 8 * 8, 4096)  # Max possible moves
        
        # Value head (position evaluation)
        self.value_conv = nn.Conv2d(num_channels, 32, 1)
        self.value_bn = nn.BatchNorm2d(32)
        self.value_fc1 = nn.Linear(32 * 8 * 8, 256)
        self.value_fc2 = nn.Linear(256, 1)
    
    def forward(self, x):
        """
        Forward pass.
        x: (batch, 12, 8, 8) board tensor
        Returns: (policy, value)
        """
        # Initial convolution
        x = F.relu(self.bn_initial(self.conv_initial(x)))
        
        # Residual block 1
        residual = x
        x = F.relu(self.res1_bn1(self.res1_conv1(x)))
        x = self.res1_bn2(self.res1_conv2(x))
        x = F.relu(x + residual)
        
        # Residual block 2
        residual = x
        x = F.relu(self.res2_bn1(self.res2_conv1(x)))
        x = self.res2_bn2(self.res2_conv2(x))
        x = F.relu(x + residual)
        
        # Policy head
        policy = F.relu(self.policy_bn(self.policy_conv(x)))
        policy = policy.view(-1, 32 * 8 * 8)
        policy = self.policy_fc(policy)
        policy = F.log_softmax(policy, dim=1)
        
        # Value head
        value = F.relu(self.value_bn(self.value_conv(x)))
        value = value.view(-1, 32 * 8 * 8)
        value = F.relu(self.value_fc1(value))
        value = torch.tanh(self.value_fc2(value))
        
        return policy, value

def count_parameters(model):
    """Count trainable parameters"""
    return sum(p.numel() for p in model.parameters() if p.requires_grad)

# Test
if __name__ == "__main__":
    model = ChessNetPOC(num_channels=64)
    print(f"Parameters: {count_parameters(model):,}")
    
    # Test forward pass
    x = torch.randn(1, 12, 8, 8)
    policy, value = model(x)
    print(f"Policy shape: {policy.shape}")
    print(f"Value shape: {value.shape}")
