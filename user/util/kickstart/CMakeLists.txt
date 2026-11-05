set(_loader "${CMAKE_CURRENT_SOURCE_DIR}")
set(_kickstart_src
    crt0-amd64.S
    kickstart.cc
    kipmgr.cc
    elf.cc
    lib.cc
    bootinfo.cc
    amd64.cc
    mbi.cc
    mbi-amd64.cc
    mbi-loader.cc
)

list(TRANSFORM _kickstart_src PREPEND "${_loader}/")
set(_elf64 "${_out}/obj/kickstart-elf64.o")
set(_bootinfo64 "${_out}/obj/kickstart-bootinfo64.o")

foreach(_variant IN ITEMS elf64 bootinfo64)
    if(_variant STREQUAL "elf64")
        set(_source elf.cc)
        set(_define ELF_64on32)
    else()
        set(_source bootinfo.cc)
        set(_define BOOTINFO_64on32)
    endif()
    
    add_custom_command(OUTPUT "${_out}/obj/kickstart-${_variant}.o"
        COMMAND "${CMAKE_CXX_COMPILER}"
        -std=c++11 -nostdinc -m32 -march=i686 -ffreestanding
        -fno-pic -fno-pie -fno-stack-protector -fno-builtin
        -fno-exceptions -fno-rtti -fno-threadsafe-statics -O2 -g
        "-I${_out}/include" "-I${_user}/include" "-I${_user}/lib/io"
        "-I${PISTACHIO_BUILTIN_INCLUDE}" "-D${_define}" -DREVISION=0
        -c "${_loader}/${_source}" -o "${_out}/obj/kickstart-${_variant}.o"
        DEPENDS "${_loader}/${_source}" "${_out}/include/config.h" VERBATIM)
endforeach()

set_source_files_properties("${_elf64}" "${_bootinfo64}" PROPERTIES GENERATED TRUE EXTERNAL_OBJECT TRUE)
add_executable(kickstart ${_kickstart_src} "${_elf64}" "${_bootinfo64}")
l4_compile(kickstart 32)

target_compile_definitions(kickstart PRIVATE ALSO_ELF64 ALSO_BOOTINFO64 REVISION=0)
l4_link(kickstart 32 "${PISTACHIO_KICKSTART_BASE}")
target_link_options(kickstart PRIVATE -Wl,-N "-Wl,-T,${_loader}/kickstart.ld")
target_link_libraries(kickstart PRIVATE io32)
set_target_properties(kickstart PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${_out}/util/kickstart")