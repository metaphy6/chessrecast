cmake_minimum_required(VERSION 3.10)
project(chess_engine C)

set(CMAKE_C_STANDARD 11)

add_library(chess_engine SHARED
    board.c
    board/board_zobrist.c
    board/board_fen.c
    board/board_attacks.c
    board/board_make.c
    movegen.c
    movegen/movegen_pawns.c
    movegen/movegen_pieces.c
    movegen/movegen_legal.c
    evaluate.c
    eval/eval_common.c
    eval/eval_mercenary.c
    eval/eval_heir.c
    eval/eval_friendly_fire.c
    eval/eval_truce.c
    eval/eval_kings_battle.c
    eval/eval_save_queen.c
    eval/eval_succession.c
    search.c
    search/heuristics_heir.c
    search/heuristics_truce.c
    search/heuristics_friendly_fire.c
    search/heuristics_kings_battle.c
    search/heuristics_mercenary.c
    bridge.c
    bridge/bridge_common.c
    bridge/bridge_friendly_fire.c
    bridge/bridge_kings_battle.c
    bridge/bridge_heir.c
    bridge/bridge_succession.c
    bridge/bridge_save_queen.c
    bridge/bridge_king_discipline.c
    replay_version.c
)

# Optimisation: Release builds get -O3
target_compile_options(chess_engine PRIVATE
    $<$<CONFIG:Release>:-O3>
    $<$<CONFIG:Debug>:-O2 -g>
)

# Export only the bridge symbols (keeps library small & clean)
if(NOT WIN32)
    target_compile_options(chess_engine PRIVATE -fvisibility=hidden)
endif()

# Link Android log library
if(ANDROID)
    find_library(log-lib log)
    target_link_libraries(chess_engine ${log-lib})
endif()
