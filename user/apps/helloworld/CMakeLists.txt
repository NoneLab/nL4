add_executable(helloworld
    "${CMAKE_CURRENT_SOURCE_DIR}/crt0-amd64.S"
    "${CMAKE_CURRENT_SOURCE_DIR}/helloworld.cc"
)
l4_compile(helloworld 64)
l4_link(helloworld 64 "${PISTACHIO_ROOTTASK_BASE}")
target_link_libraries(helloworld PRIVATE
    l4
    io64
)
set_target_properties(helloworld PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY
    "${_out}/apps/bench/pingpong"
)