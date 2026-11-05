# SPDX-License-Identifier: BSD-2-Clause
function(l4_compile name bits)

    target_include_directories(${name} PRIVATE
        "${_out}/include" "${_user}/include" "${_user}/lib/io"
        "${PISTACHIO_BUILTIN_INCLUDE}"
    )

    target_compile_options(${name} PRIVATE
        -nostdinc "-I${PISTACHIO_BUILTIN_INCLUDE}" -fno-pic -fno-pie
        "$<$<COMPILE_LANGUAGE:CXX>:-ffreestanding;-fno-stack-protector;-fno-builtin;-fno-exceptions;-fno-rtti;-fno-threadsafe-statics;-fno-asynchronous-unwind-tables;-fno-unwind-tables;-Wall;-Wno-unused-parameter;-O2;-g>"
        "$<$<COMPILE_LANGUAGE:ASM>:-DASSEMBLY>")

    if(bits EQUAL 32)
        target_compile_options(${name} PRIVATE -m32 -march=i686)
    else()
        target_compile_options(${name} PRIVATE -m64 -mno-red-zone)
    endif()

endfunction()

function(l4_link name bits base)
    if(bits EQUAL 32)
        target_link_options(${name} PRIVATE -m32 -nostdlib -no-pie -static -Wl,-m,elf_i386 -Wl,-e,_start -Wl,--build-id=none)
    else()
        target_link_options(${name} PRIVATE -m64 -nostdlib -no-pie -static -Wl,-m,elf_x86_64 -Wl,-e,_start -Wl,--build-id=none)
    endif()
    target_link_options(${name} PRIVATE "-Wl,-Ttext,${base}")
endfunction()