set(_io_sources
    get_hex.cc
    print.cc
    amd64.cc
)

add_library(io64 STATIC ${_io_sources})
l4_compile(io64 64)

add_library(io32 STATIC ${_io_sources})
l4_compile(io32 32)