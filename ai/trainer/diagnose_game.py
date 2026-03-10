#!/usr/bin/env python3
"""
Diagnostic tool: play MCTS games and log every move in detail.
This lets us watch exactly what the AI is doing and diagnose problems.
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import torch
import chess
import numpy as np
import math
from network import ChessNetPOC
from selfplay import ImprovedSelfPlay

# Import MercenaryBoard from mods
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'mods', 'mercenary'))
from mercenary import MercenaryBoard

PIECE_NAMES = {
    chess.PAWN: 'P', chess.KNIGHT: 'N', chess.BISHOP: 'B',
    chess.ROOK: 'R', chess.QUEEN: 'Q', chess.KING: 'K',
}
PIECE_VALUES = {
    chess.PAWN: 1.0, chess.KNIGHT: 3.0, chess.BISHOP: 3.0,
    chess.ROOK: 5.0, chess.QUEEN: 9.0,
}

def describe_move(board, move):
    """Create a human-readable description of a move."""
    piece = board.piece_at(move.from_square)
    victim = board.piece_at(move.to_square)
    if not piece:
        return f"{move.uci()} (???)"
    pname = PIECE_NAMES.get(piece.piece_type, '?')
    color = 'W' if piece.color == chess.WHITE else 'B'
    desc = f"{color}{pname} {chess.square_name(move.from_square)}->{chess.square_name(move.to_square)}"
    if victim:
        vname = PIECE_NAMES.get(victim.piece_type, '?')
        vval = PIECE_VALUES.get(victim.piece_type, 0)
        desc += f" CAPTURES {vname}(val={vval})"
    return desc

def find_all_captures(game):
    """List all captures available in the current position."""
    captures = []
    legal = game.get_legal_moves()
    for m in legal:
        victim = game.board.piece_at(m.to_square)
        if victim and victim.piece_type != chess.KING:
            attacker = game.board.piece_at(m.from_square)
            captures.append((m, attacker, victim))
    return captures

def material_count(board):
    """Count material for both sides."""
    w, b = 0.0, 0.0
    for sq in chess.SQUARES:
        p = board.piece_at(sq)
        if p and p.piece_type != chess.KING:
            v = PIECE_VALUES.get(p.piece_type, 0)
            if p.color == chess.WHITE:
                w += v
            else:
                b += v
    return w, b

def board_ascii(board):
    """Print board in a compact format."""
    lines = []
    for rank in range(7, -1, -1):
        row = f"  {rank+1} "
        for file in range(8):
            sq = chess.square(file, rank)
            p = board.piece_at(sq)
            if p:
                row += p.symbol() + ' '
            else:
                row += '. '
        lines.append(row)
    lines.append("    a b c d e f g h")
    return '\n'.join(lines)

def play_diagnostic_game(game_num, num_sims=300, heuristic_weight=0.95):
    """Play one game with full move-by-move analysis."""
    print(f"\n{'='*70}")
    print(f"  GAME {game_num} — {num_sims} MCTS sims, heuristic_weight={heuristic_weight}")
    print(f"{'='*70}")
    
    # Create fresh untrained model (simulates iteration 1)
    model = ChessNetPOC(num_channels=128, num_res_blocks=10, input_channels=17)
    model.eval()
    
    sp = ImprovedSelfPlay(
        model, device='cpu', num_simulations=num_sims,
        batch_size=64, game_class=MercenaryBoard,
        heuristic_weight=heuristic_weight)
    
    game = MercenaryBoard()
    move_count = 0
    missed_captures = 0
    blunders = 0
    repetitions = 0
    last_moves = []  # Track last N moves for repetition detection
    
    print(f"\nStarting position:")
    print(board_ascii(game.board))
    wm, bm = material_count(game.board)
    print(f"Material: W={wm} B={bm}")
    
    while not game.is_game_over() and move_count < 200:
        legal_moves = game.get_legal_moves()
        if not legal_moves:
            break
        
        turn = 'WHITE' if game.board.turn else 'BLACK'
        
        # Find available captures before move
        captures = find_all_captures(game)
        
        # Get heuristic eval before move
        h_eval = game.heuristic_eval()
        
        # Use the same logic as play_game: forced capture check
        forced, forced_score = sp._find_winning_capture(game, legal_moves)
        
        if forced is not None:
            chosen_move = forced
            move_source = "FORCED_CAPTURE"
            move_probs = np.zeros(len(legal_moves))
            for idx, m in enumerate(legal_moves):
                if m == forced:
                    move_probs[idx] = 1.0
                    break
        else:
            # MCTS search
            temperature = sp._get_temperature(move_count, 'decay')
            move_probs = sp._mcts_search(game, legal_moves, temperature)
            
            # Smart move selection with soft repetition + reverse-move penalty
            ranked = np.argsort(move_probs)[::-1]
            chosen_move = None
            best_adj = -1.0

            reverse_pair = None
            if game.board.move_stack:
                last = game.board.move_stack[-1]
                reverse_pair = (last.to_square, last.from_square)

            # Wider cycle detection
            our_recent_dests = set()
            stack = list(game.board.move_stack)
            for i in range(2, min(9, len(stack) + 1), 2):
                our_recent_dests.add(stack[-i].to_square)

            has_history = (hasattr(game, 'position_history')
                           and game.position_history)

            for idx in ranked[:15]:
                prob = move_probs[idx]
                if prob < 0.005:
                    continue
                candidate = legal_moves[idx]

                rep_mult = 1.0
                if has_history:
                    game.board.push(candidate)
                    pos = game.board.fen().split()[0]
                    game.board.pop()
                    rep = game.position_history.count(pos)
                    if rep >= 3:
                        rep_mult = 0.01
                    elif rep >= 2:
                        rep_mult = 0.04
                    elif rep >= 1:
                        rep_mult = 0.25

                if (reverse_pair and
                        candidate.from_square == reverse_pair[0] and
                        candidate.to_square == reverse_pair[1]):
                    rep_mult *= 0.12
                elif candidate.to_square in our_recent_dests:
                    rep_mult *= 0.45

                adj = prob * rep_mult
                if adj > best_adj:
                    best_adj = adj
                    chosen_move = candidate
                    chosen_move_idx = idx

            if chosen_move is None:
                chosen_move_idx = int(ranked[0])
                chosen_move = legal_moves[chosen_move_idx]
            move_source = "MCTS"
        
        move_count += 1
        
        # Analyze the chosen move
        move_desc = describe_move(game.board, chosen_move)
        is_capture = game.board.piece_at(chosen_move.to_square) is not None
        
        # Check if there were captures available but we didn't take one
        capture_missed = False
        if captures and not is_capture and move_source != "FORCED_CAPTURE":
            # Were any of the captures "free" (higher value victim)?
            for cap_move, attacker, victim in captures:
                if attacker and victim:
                    atk_val = PIECE_VALUES.get(attacker.piece_type, 0)
                    vic_val = PIECE_VALUES.get(victim.piece_type, 0)
                    if vic_val >= atk_val:  # Good capture available
                        capture_missed = True
                        missed_captures += 1
                        break
        
        # Check for repetitive moves
        move_uci = chosen_move.uci()
        is_repetitive = False
        if len(last_moves) >= 4:
            # Check if this move appeared in last 4 moves for same side
            same_side_moves = last_moves[-4::2] if len(last_moves) >= 4 else []
            if move_uci in [m for m in same_side_moves]:
                is_repetitive = True
                repetitions += 1
        last_moves.append(move_uci)
        
        # Check for blunder: moving valuable piece next to enemy pawn
        piece = game.board.piece_at(chosen_move.from_square)
        is_blunder = False
        if piece and piece.piece_type not in (chess.PAWN, chess.KING):
            to_r = chess.square_rank(chosen_move.to_square)
            to_f = chess.square_file(chosen_move.to_square)
            for dr in range(-1, 2):
                for df in range(-1, 2):
                    if dr == 0 and df == 0:
                        continue
                    nr, nf = to_r + dr, to_f + df
                    if 0 <= nr <= 7 and 0 <= nf <= 7:
                        adj = game.board.piece_at(chess.square(nf, nr))
                        if adj and adj.color != piece.color and adj.piece_type == chess.PAWN:
                            my_val = PIECE_VALUES.get(piece.piece_type, 0)
                            if my_val >= 3.0 and not is_capture:
                                is_blunder = True
                                blunders += 1
        
        # Print move analysis
        flags = []
        if is_capture: flags.append("** CAPTURE")
        if capture_missed: flags.append("!! MISSED FREE CAPTURE")
        if is_repetitive: flags.append("~~ REPEAT")
        if is_blunder: flags.append("XX BLUNDER")
        if move_source == "FORCED_CAPTURE": flags.append(">> FORCED")
        flag_str = ' '.join(flags) if flags else ""
        
        # Top 3 MCTS candidates
        top3_idx = np.argsort(move_probs)[-3:][::-1]
        top3 = [(legal_moves[i].uci(), f"{move_probs[i]:.3f}") for i in top3_idx]
        top3_str = ', '.join([f"{m}({p})" for m, p in top3])
        
        print(f"\n  Move {move_count:3d} [{turn:5s}] {move_desc}  "
              f"[src={move_source}] heval={h_eval:+.3f} {flag_str}")
        if captures:
            cap_list = [describe_move(game.board, c[0]) for c in captures[:5]]
            print(f"           Available captures: {', '.join(cap_list)}")
        if move_source == "MCTS":
            print(f"           Top MCTS: {top3_str}")
        
        # Make the move
        game.make_move(chosen_move)
        wm, bm = material_count(game.board)
        
        # Print board every 20 moves or on important events
        if move_count % 20 == 0 or capture_missed or is_blunder:
            print(f"           Material: W={wm} B={bm} (diff={wm-bm:+.0f})")
            if capture_missed or is_blunder:
                print(board_ascii(game.board))
    
    # Game over
    result = game.get_result()
    wm, bm = material_count(game.board)
    print(f"\n{'─'*70}")
    print(f"  GAME {game_num} RESULT: {result} in {move_count} moves")
    print(f"  Final material: W={wm} B={bm}")
    print(f"  Issues: {missed_captures} missed captures, {blunders} blunders, {repetitions} repetitions")
    print(board_ascii(game.board))
    print(f"{'─'*70}")
    
    return {
        'result': result,
        'moves': move_count,
        'missed_captures': missed_captures,
        'blunders': blunders,
        'repetitions': repetitions,
        'w_material': wm,
        'b_material': bm,
    }


if __name__ == '__main__':
    num_games = 3
    num_sims = 100  # Match Docker adaptive min (was 50)
    
    print(f"Running {num_games} diagnostic games with {num_sims} MCTS simulations...")
    print(f"Using untrained model + heuristic_weight=0.95 (iteration 1 conditions)")
    
    all_results = []
    for g in range(1, num_games + 1):
        stats = play_diagnostic_game(g, num_sims=num_sims, heuristic_weight=0.95)
        all_results.append(stats)
    
    print(f"\n{'='*70}")
    print(f"  SUMMARY OF {num_games} GAMES")
    print(f"{'='*70}")
    for i, r in enumerate(all_results, 1):
        print(f"  Game {i}: {r['result']:20s} | {r['moves']:3d} moves | "
              f"missed_cap={r['missed_captures']} blunders={r['blunders']} "
              f"repeats={r['repetitions']}")
    
    total_missed = sum(r['missed_captures'] for r in all_results)
    total_blunders = sum(r['blunders'] for r in all_results)
    total_repeats = sum(r['repetitions'] for r in all_results)
    avg_moves = sum(r['moves'] for r in all_results) / len(all_results)
    
    print(f"\n  Totals: {total_missed} missed captures, {total_blunders} blunders, "
          f"{total_repeats} repetitions")
    print(f"  Avg game length: {avg_moves:.0f} moves")
