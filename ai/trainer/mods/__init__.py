"""
Game Mods Package
=================
Contains implementations of various chess game mods.
Each mod lives in its own subfolder with rules + board + training.
"""
from .mercenary import MercenaryMode, MercenaryBoard

__all__ = [
    'MercenaryMode',
    'MercenaryBoard',
]
