#!/usr/bin/env python3
"""
Chess dataset utilities for PyTorch training.

Provides dataset classes for loading chess training data.
"""

import torch
from torch.utils.data import Dataset


class ChessDataset(Dataset):
    """
    PyTorch Dataset for chess training data.
    
    Each sample contains:
        - state: Board state tensor (8x8x12)
        - policy: Move probability distribution
        - value: Position evaluation (-1 to 1)
    
    Args:
        game_history: List of training samples with 'state', 'policy', 'value' keys
    
    Usage:
        dataset = ChessDataset(game_history)
        dataloader = DataLoader(dataset, batch_size=512, shuffle=True)
        for states, policies, values in dataloader:
            # ... training loop ...
    """
    
    def __init__(self, game_history):
        self.data = game_history

    def __len__(self):
        return len(self.data)

    def __getitem__(self, idx):
        entry = self.data[idx]
        return (
            torch.from_numpy(entry['state']).float(),
            torch.from_numpy(entry['policy']).float(),
            torch.tensor([entry['value']], dtype=torch.float32)
        )
