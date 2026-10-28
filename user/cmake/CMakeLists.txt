# SPDX-License-Identifier: BSD-2-Clause
set(_user "${CMAKE_SOURCE_DIR}/user")
set(_out "${CMAKE_BINARY_DIR}/user")
file(MAKE_DIRECTORY "${_out}/include")
file(WRITE "${_out}/include/config.h" "/* CMake-generated L4 userland settings. */\n#ifndef L4_USER_MODERN_CONFIG_H\n#define L4_USER_MODERN_CONFIG_H\n#define CONFIG_COMPORT ${PISTACHIO_COMPORT}\n#define CONFIG_COMSPEED ${PISTACHIO_COMSPEED}\n#endif\n")

function(l4_compile name bits)
  target_include_directories(${name} PRIVATE
    "${_out}/include" "${_user}/include" "${_user}/lib/io"
    "${PISTACHIO_BUILTIN_INCLUDE}")
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
    target_link_options(${name} PRIVATE -m32 -nostdlib -no-pie -static
      -Wl,-m,elf_i386 -Wl,-e,_start -Wl,--build-id=none)
  else()
    target_link_options(${name} PRIVATE -m64 -nostdlib -no-pie -static
      -Wl,-m,elf_x86_64 -Wl,-z,max-page-size=4096 -Wl,-e,_start -Wl,--build-id=none)
  endif()
  target_link_options(${name} PRIVATE "-Wl,-Ttext,${base}")
endfunction()

add_library(l4 STATIC "${_user}/lib/l4/debug.cc" "${_user}/lib/l4/amd64.cc")
l4_compile(l4 64)
add_library(io64 STATIC "${_user}/lib/io/get_hex.cc" "${_user}/lib/io/print.cc" "${_user}/lib/io/amd64.cc")
l4_compile(io64 64)
add_library(io32 STATIC "${_user}/lib/io/get_hex.cc" "${_user}/lib/io/print.cc" "${_user}/lib/io/amd64.cc")
l4_compile(io32 32)

add_executable(sigma0
  "${_user}/serv/sigma0/crt0-amd64.S"
  "${_user}/serv/sigma0/sigma0_io.cc" "${_user}/serv/sigma0/sigma0.cc"
  "${_user}/serv/sigma0/sigma0_mem.cc" "${_user}/serv/sigma0/region.cc")
l4_compile(sigma0 64)
l4_link(sigma0 64 "${PISTACHIO_SIGMA0_BASE}")
target_link_libraries(sigma0 PRIVATE l4 io64)
set_target_properties(sigma0 PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${_out}/serv/sigma0")

set(_ping32 "${_out}/obj/pingpong-amd64-32.o")
file(MAKE_DIRECTORY "${_out}/obj")
add_custom_command(OUTPUT "${_ping32}"
  COMMAND "${CMAKE_CXX_COMPILER}"
    -std=c++11 -nostdinc -m32 -march=i686 -ffreestanding
    -fno-pic -fno-pie -fno-stack-protector -fno-builtin
    -fno-exceptions -fno-rtti -fno-threadsafe-statics -O2 -g
    "-I${_out}/include" "-I${_user}/include" "-I${_user}/lib/io"
    "-I${PISTACHIO_BUILTIN_INCLUDE}"
    -c "${_user}/apps/bench/pingpong/pingpong-amd64-32.cc"
    -o "${_out}/obj/pingpong-amd64-32.elf32.o"
  COMMAND "${PISTACHIO_OBJCOPY}" -g -O elf64-x86-64
    "${_out}/obj/pingpong-amd64-32.elf32.o" "${_ping32}"
  DEPENDS "${_user}/apps/bench/pingpong/pingpong-amd64-32.cc" "${_out}/include/config.h"
  VERBATIM)
set_source_files_properties("${_ping32}" PROPERTIES GENERATED TRUE EXTERNAL_OBJECT TRUE)
add_executable(pingpong
  "${_user}/apps/bench/pingpong/crt0-amd64.S"
  "${_user}/apps/bench/pingpong/pingpong.cc" "${_ping32}")
l4_compile(pingpong 64)
l4_link(pingpong 64 "${PISTACHIO_ROOTTASK_BASE}")
target_link_libraries(pingpong PRIVATE l4 io64)
set_target_properties(pingpong PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${_out}/apps/bench/pingpong")

set(_test_dir "${_user}/apps/l4test")
set(_testsrc main.cc assert.cc menu.cc threads.cc string.cc ipc.cc ipc-string.cc
  ipc-pf.cc ipc-smp.cc kip.cc mem.cc sig0.cc exreg.cc tcontrol.cc schedule.cc
  amd64/crt0.S amd64/help.cc amd64/tests.cc)
list(TRANSFORM _testsrc PREPEND "${_test_dir}/")
add_executable(l4test EXCLUDE_FROM_ALL ${_testsrc})
l4_compile(l4test 64)
target_include_directories(l4test PRIVATE "${_test_dir}/amd64")
l4_link(l4test 64 "${PISTACHIO_ROOTTASK_BASE}")
target_link_libraries(l4test PRIVATE l4 io64)
set_target_properties(l4test PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${_out}/apps/l4test")

set(_loader "${_user}/util/kickstart")
set(_kicksrc crt0-amd64.S kickstart.cc kipmgr.cc elf.cc lib.cc bootinfo.cc
  amd64.cc mbi.cc mbi-amd64.cc mbi-loader.cc)
list(TRANSFORM _kicksrc PREPEND "${_loader}/")
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
add_executable(kickstart ${_kicksrc} "${_elf64}" "${_bootinfo64}")
l4_compile(kickstart 32)
target_compile_definitions(kickstart PRIVATE ALSO_ELF64 ALSO_BOOTINFO64 REVISION=0)
l4_link(kickstart 32 "${PISTACHIO_KICKSTART_BASE}")
target_link_options(kickstart PRIVATE -Wl,-N "-Wl,-T,${_loader}/kickstart.ld")
target_link_libraries(kickstart PRIVATE io32)
set_target_properties(kickstart PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${_out}/util/kickstart")

add_custom_target(userland DEPENDS kickstart sigma0 pingpong)
