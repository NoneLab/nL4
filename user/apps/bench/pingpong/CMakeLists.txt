set(_ping32 "${_out}/obj/pingpong-amd64-32.o")
file(MAKE_DIRECTORY "${_out}/obj")

add_custom_command(OUTPUT "${_ping32}"
    COMMAND "${CMAKE_CXX_COMPILER}"
        -std=c++11 -nostdinc -m32 -march=i686 -ffreestanding
        -fno-pic -fno-pie -fno-stack-protector -fno-builtin
        -fno-exceptions -fno-rtti -fno-threadsafe-statics -O2 -g
        "-I${_out}/include" "-I${_user}/include" "-I${_user}/lib/io"
        "-I${PISTACHIO_BUILTIN_INCLUDE}"
        -c "${CMAKE_CURRENT_SOURCE_DIR}/pingpong-amd64-32.cc"
        -o "${_out}/obj/pingpong-amd64-32.elf32.o"
    COMMAND "${PISTACHIO_OBJCOPY}" -g -O elf64-x86-64
        "${_out}/obj/pingpong-amd64-32.elf32.o" "${_ping32}"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/pingpong-amd64-32.cc" "${_out}/include/config.h"
    VERBATIM
)

set_source_files_properties("${_ping32}" PROPERTIES GENERATED TRUE EXTERNAL_OBJECT TRUE)
add_executable(pingpong
    "${CMAKE_CURRENT_SOURCE_DIR}/crt0-amd64.S"
    "${CMAKE_CURRENT_SOURCE_DIR}/pingpong.cc" 
    "${_ping32}"
)
l4_compile(pingpong 64)
l4_link(pingpong 64 "${PISTACHIO_ROOTTASK_BASE}")
target_link_libraries(pingpong PRIVATE
    l4
    io64
)
set_target_properties(pingpong PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY
    "${_out}/apps/bench/pingpong"
)