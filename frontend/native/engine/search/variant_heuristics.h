#ifndef CHESS_SEARCH_VARIANT_HEURISTICS_H
#define CHESS_SEARCH_VARIANT_HEURISTICS_H

#include "../board.h"

int search_heir_f_pawn_block_move_penalty(const Board *b, Move m);
bool search_heir_position_volatile(const Board *b);
bool search_heir_critical_move(const Board *b, Move m);
bool search_heir_king_under_direct_fire(const Board *b);
bool search_heir_tactical_capture(const Board *b, Move m, int see);
int search_heir_early_queen_sortie_penalty(const Board *b, Move m);
bool search_heir_is_tactical_capture_candidate(const Board *b, Move m);

int search_truce_undeveloped_minor_count(const Board *b, Color side);
int search_truce_minor_development_score(const Board *b, Move m, Color side);
int search_truce_early_queen_sortie_penalty(const Board *b, Move m, Color side);
int search_truce_quiet_pawn_score(const Board *b, Move m, Color side);

int search_kb_phase1_forward_rank(Color side, Square sq);
bool search_kb_full_skill_variety_enabled(const Board *b);
int search_kb_full_skill_variety_margin(const Board *b);
int search_kb_full_skill_tiebreak_band(const Board *b);
bool search_kb_phase1_any_pawn_capture_available(const Board *b, Color side);
int search_kb_phase1_king_activation_score(const Board *b, Move m, Color side);
int search_kb_phase1_pawn_race_score(const Board *b, Move m, Color side);
int search_kb_unlocked_development_score(const Board *b, Move m, Color side);
int search_kb_unlocked_king_shelter_score(const Board *b, Move m, Color side);
int search_kb_unlocked_queen_pressure_score(const Board *b, Move m, Color side);
int search_kb_unlocked_king_safety_score(const Board *b, Move m, Color side);

bool search_kb_unlocked_is_queen_pressure_move(const Board *b, Move m, Color side);
bool search_kb_unlocked_is_king_safety_move(const Board *b, Move m, Color side);
bool search_kb_unlocked_is_shelter_move(const Board *b, Move m, Color side);
bool search_kb_unlocked_is_development_move(const Board *b, Move m, Color side);

#endif