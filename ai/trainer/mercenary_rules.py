"""
Mercenary Chess Mode Implementation
====================================
DEPRECATED: This file is maintained for backward compatibility only.
Please import from modes.mercenary instead:
    from modes.mercenary import MercenaryBoard, MercenaryMode

Pawns move and capture like Kings (1 square in any direction).
No en passant, no two-square initial move, no pawn promotion.

Special draw rules:
- K+pieces vs K: 50 half-moves (25+25) to mate
- Normal positions: 100 half-moves (50+50) standard rule
- K vs K: Draw
- K+N vs K+N (no pawns): Draw
"""
# Import from new modular structure
from modes.mercenary import MercenaryBoard

__all__ = ['MercenaryBoard']
