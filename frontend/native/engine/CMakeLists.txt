cmake_minimum_required(VERSION 3.10)
project(chess_engine C)

set(CMAKE_C_STANDARD 11)

add_library(chess_engine SHARED
    board.c
    movegen.c
    evaluate.c
    search.c
    search/variant_heuristics.c
    bridge.c
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
