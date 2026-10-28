# SPDX-License-Identifier: BSD-2-Clause
include("${CMAKE_SOURCE_DIR}/cmake/KernelSources.cmake")
string(REPLACE "-" "_" _profile_id "${PISTACHIO_PROFILE}")
set(_manifest_var "KERNEL_SOURCES_${_profile_id}")
set(_kernel_sources "${${_manifest_var}}")
if(NOT _kernel_sources)
  message(FATAL_ERROR "No kernel source manifest for ${PISTACHIO_PROFILE}")
endif()
set(_out "${CMAKE_BINARY_DIR}/kernel/${PISTACHIO_PROFILE}")
set(_inc "${_out}/include")
set(_config "${_out}/config/config.h")
set(_headers "${_out}/generated/headers.stamp")
set(_cfgbase "${CMAKE_SOURCE_DIR}/kernel/config/profiles/${PISTACHIO_PROFILE}")
file(MAKE_DIRECTORY "${_out}/generated")
set(_kdb_source_manifest "")
foreach(_entry IN LISTS _kernel_sources)
  if(_entry MATCHES "^kdb/.*\\.cc$")
    string(APPEND _kdb_source_manifest "${CMAKE_SOURCE_DIR}/kernel/${_entry}\n")
  endif()
endforeach()
file(WRITE "${_out}/generated/kdb_sources.lst" "${_kdb_source_manifest}")
file(GLOB_RECURSE _kernel_header_deps CONFIGURE_DEPENDS
  "${CMAKE_SOURCE_DIR}/kernel/src/*.h" "${CMAKE_SOURCE_DIR}/kernel/src/*.ldi"
  "${CMAKE_SOURCE_DIR}/kernel/kdb/*.h")
add_custom_command(OUTPUT "${_headers}"
  COMMAND "${PISTACHIO_BASH}" "${CMAKE_SOURCE_DIR}/cmake/generate-kernel.sh"
    "${CMAKE_SOURCE_DIR}" "${_out}" "${PISTACHIO_PROFILE}" "${PISTACHIO_SUBARCH}"
    "${CMAKE_CXX_COMPILER}" "${PISTACHIO_NM}" "${PISTACHIO_AWK}"
  DEPENDS "${CMAKE_SOURCE_DIR}/cmake/generate-kernel.sh"
    "${CMAKE_SOURCE_DIR}/mk/asm-symbols.awk"
    "${_cfgbase}/config.h" "${_cfgbase}/.config" ${_kernel_header_deps}
  VERBATIM)
add_custom_target(pistachio-kernel-headers DEPENDS "${_headers}")
set(_actual_sources)
foreach(_entry IN LISTS _kernel_sources)
  if(_entry STREQUAL "src/arch/x86/x64/init32.cc")
    continue()
  endif()
  list(APPEND _actual_sources "${CMAKE_SOURCE_DIR}/kernel/${_entry}")
endforeach()
add_library(pistachio-kernel-objs OBJECT ${_actual_sources})
add_dependencies(pistachio-kernel-objs pistachio-kernel-headers)
# C++ and C retain their original per-file languages. Assembly is compiled
# by the ASM driver and not incorrectly parsed as C++.
target_include_directories(pistachio-kernel-objs PRIVATE
  "${_inc}" "${CMAKE_SOURCE_DIR}/kernel/src"
  "${CMAKE_SOURCE_DIR}/kernel/src/generic" "${PISTACHIO_BUILTIN_INCLUDE}")
set(_definitions
  "-Ux86" "-U${PISTACHIO_SUBARCH}" "-Up4" "-Upc99" "-Uv4" "-Urr"
  "-D__ARCH__=x86" "-D__SUBARCH__=${PISTACHIO_SUBARCH}"
  "-D__CPU__=p4" "-D__PLATFORM__=pc99" "-D__API__=v4" "-D__SCHED__=rr")
set(_includes
  "SHELL:-imacros ${_config}"
  "SHELL:-imacros ${CMAKE_SOURCE_DIR}/kernel/src/generic/macros.h"
  "SHELL:-include ${CMAKE_SOURCE_DIR}/kernel/src/generic/config.h")
set(_flags -nostdinc -ffreestanding -fno-pic -fno-pie -fno-stack-protector
  -fno-builtin -fno-omit-frame-pointer -Wall -Wno-unused-parameter -O2)
set(_cpu_opts -mno-mmx -mno-sse -mno-sse2 -mno-sse3)
if(PISTACHIO_SUBARCH STREQUAL "x64")
  list(APPEND _cpu_opts -m64 -mcmodel=kernel -mno-red-zone)
  set(_emulation elf_x86_64)
  set(_ld_opts -n)
else()
  list(APPEND _cpu_opts -m32 -mpreferred-stack-boundary=2)
  set(_emulation elf_i386)
  set(_ld_opts)
endif()
target_compile_options(pistachio-kernel-objs PRIVATE
  "-I${PISTACHIO_BUILTIN_INCLUDE}" ${_definitions} ${_includes} ${_flags} ${_cpu_opts}
  "$<$<COMPILE_LANGUAGE:C,CXX>:SHELL:-include ${CMAKE_SOURCE_DIR}/kernel/src/generic/types.h>"
  "$<$<COMPILE_LANGUAGE:CXX>:-fno-rtti;-fno-exceptions;-fno-threadsafe-statics>"
  "$<$<COMPILE_LANGUAGE:ASM>:-DASSEMBLY>")

set(_extra_obj)
if(PISTACHIO_SUBARCH STREQUAL "x64")
  set(_init_obj "${_out}/generated/init32.o")
  add_custom_command(OUTPUT "${_init_obj}"
    COMMAND "${CMAKE_CXX_COMPILER}"
      -std=c++11 ${_definitions}
      -imacros "${_config}" -imacros "${CMAKE_SOURCE_DIR}/kernel/src/generic/macros.h"
      -include "${CMAKE_SOURCE_DIR}/kernel/src/generic/config.h" ${_flags}
      -fno-rtti -fno-exceptions -fno-threadsafe-statics
      -fno-asynchronous-unwind-tables -fno-unwind-tables
      -Wa,--64
      -m32 -mno-mmx -mno-sse -mno-sse2 -mno-sse3 -DX64_32BIT_CODE
      "-I${_inc}" "-I${CMAKE_SOURCE_DIR}/kernel/src"
      "-I${CMAKE_SOURCE_DIR}/kernel/src/generic" "-I${PISTACHIO_BUILTIN_INCLUDE}"
      -include "${CMAKE_SOURCE_DIR}/kernel/src/generic/types.h"
      -c "${CMAKE_SOURCE_DIR}/kernel/src/arch/x86/x64/init32.cc"
      -o "${_init_obj}"
    DEPENDS "${_headers}" "${CMAKE_SOURCE_DIR}/kernel/src/arch/x86/x64/init32.cc"
    VERBATIM)
  set(_extra_obj "${_init_obj}")
endif()
execute_process(COMMAND "${CMAKE_CXX_COMPILER}" -print-libgcc-file-name
  OUTPUT_VARIABLE _libgcc OUTPUT_STRIP_TRAILING_WHITESPACE COMMAND_ERROR_IS_FATAL ANY)
if(PISTACHIO_SUBARCH STREQUAL "x64")
  set(_runtime_lib "${_libgcc}")
else()
  set(_runtime_lib)
endif()
set(PISTACHIO_KERNEL_ELF "${_out}/x86-kernel" PARENT_SCOPE)
add_custom_command(OUTPUT "${_out}/x86-kernel"
  COMMAND "${PISTACHIO_LD}" -m "${_emulation}" -z max-page-size=4096 ${_ld_opts}
    -static -T "${_out}/linker.lds" -o "${_out}/x86-kernel"
    $<TARGET_OBJECTS:pistachio-kernel-objs> ${_extra_obj} ${_runtime_lib}
  DEPENDS pistachio-kernel-objs "${_headers}" ${_extra_obj}
  COMMAND_EXPAND_LISTS VERBATIM)
add_custom_target(pistachio-kernel ALL DEPENDS "${_out}/x86-kernel")
message(STATUS "Kernel: ${PISTACHIO_PROFILE} (${_emulation}); ${_out}/x86-kernel")
