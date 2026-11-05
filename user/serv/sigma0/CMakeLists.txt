add_executable(sigma0
    crt0-amd64.S
    sigma0_io.cc
    sigma0.cc
    sigma0_mem.cc
    region.cc
)

l4_compile(sigma0 64)
l4_link(sigma0 64 "${PISTACHIO_SIGMA0_BASE}")
target_link_libraries(sigma0 PRIVATE l4 io64)
set_target_properties(sigma0 PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${_out}/serv/sigma0")
