"""
Mercenary Mod Package
=====================
Pawns move and capture like Kings (1 square any direction).
No en passant, no two-square initial move, no pawn promotion.
"""
from .mercenary import MercenaryMode, MercenaryBoard

__all__ = [
    'MercenaryMode',
    'MercenaryBoard',
]
