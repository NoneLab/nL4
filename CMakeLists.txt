# SPDX-License-Identifier: BSD-2-Clause
cmake_minimum_required(VERSION 3.20)
project(PistachioL4 LANGUAGES C CXX ASM)

# C/C++ are deliberately separate. GNU C++/assembly extensions required by L4
# ABI are preserved; building does not imply strict ISO language conformance.
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_POSITION_INDEPENDENT_CODE OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(PISTACHIO_PROFILE "x86-x64-p4-nokdb" CACHE STRING "Kernel configuration profile")
set_property(CACHE PISTACHIO_PROFILE PROPERTY STRINGS
  x86-x64-p4-nokdb x86-x32-p4-nokdb x86-x64-p4-debug)
set(PISTACHIO_ROOT_TASK "pingpong" CACHE STRING "Boot Root Task: pingpong or l4test")
set_property(CACHE PISTACHIO_ROOT_TASK PROPERTY STRINGS pingpong l4test)
set(PISTACHIO_COMPORT 0 CACHE STRING "Serial port for L4 userland")
set(PISTACHIO_COMSPEED 115200 CACHE STRING "Serial speed")
set(PISTACHIO_KICKSTART_BASE 0x00100000 CACHE STRING "Kickstart link address")
set(PISTACHIO_SIGMA0_BASE 0x00f00000 CACHE STRING "Sigma0 link address")
set(PISTACHIO_ROOTTASK_BASE 0x01000000 CACHE STRING "Root task link address")
if(NOT PISTACHIO_PROFILE MATCHES "^x86-(x64|x32)-p4-(nokdb|debug)$")
  message(FATAL_ERROR "Unsupported PISTACHIO_PROFILE: ${PISTACHIO_PROFILE}")
endif()
if(NOT EXISTS "${CMAKE_SOURCE_DIR}/kernel/config/profiles/${PISTACHIO_PROFILE}/config.h")
  message(FATAL_ERROR "No configuration for ${PISTACHIO_PROFILE}")
endif()
if(NOT PISTACHIO_ROOT_TASK MATCHES "^(pingpong|l4test)$")
  message(FATAL_ERROR "PISTACHIO_ROOT_TASK must be pingpong or l4test")
endif()
string(REGEX REPLACE "^x86-(x64|x32)-.*$" "\\1" PISTACHIO_SUBARCH "${PISTACHIO_PROFILE}")

find_program(PISTACHIO_LD NAMES ld REQUIRED)
find_program(PISTACHIO_NM NAMES nm REQUIRED)
find_program(PISTACHIO_OBJCOPY NAMES objcopy REQUIRED)
find_program(PISTACHIO_AWK NAMES awk REQUIRED)
find_program(PISTACHIO_BASH NAMES bash REQUIRED)
execute_process(COMMAND "${CMAKE_CXX_COMPILER}" -print-file-name=include
  OUTPUT_VARIABLE PISTACHIO_BUILTIN_INCLUDE OUTPUT_STRIP_TRAILING_WHITESPACE
  COMMAND_ERROR_IS_FATAL ANY)

add_subdirectory(kernel/cmake)
if(PISTACHIO_SUBARCH STREQUAL "x64")
  add_subdirectory(user/cmake)
endif()

if(PISTACHIO_SUBARCH STREQUAL "x64")
  set(_boot "${CMAKE_BINARY_DIR}/boot/${PISTACHIO_PROFILE}")
  set(_staged "${_boot}/kickstart" "${_boot}/x86-kernel" "${_boot}/sigma0" "${_boot}/roottask")
  set(_root_image "$<IF:$<STREQUAL:${PISTACHIO_ROOT_TASK},pingpong>,$<TARGET_FILE:pingpong>,$<TARGET_FILE:l4test>>")
  add_custom_command(OUTPUT ${_staged}
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${_boot}"
    COMMAND "${CMAKE_COMMAND}" -E copy "$<TARGET_FILE:kickstart>" "${_boot}/kickstart"
    COMMAND "${CMAKE_COMMAND}" -E copy "${PISTACHIO_KERNEL_ELF}" "${_boot}/x86-kernel"
    COMMAND "${CMAKE_COMMAND}" -E copy "$<TARGET_FILE:sigma0>" "${_boot}/sigma0"
    COMMAND "${CMAKE_COMMAND}" -E copy "${_root_image}" "${_boot}/roottask"
    DEPENDS pistachio-kernel kickstart sigma0 ${PISTACHIO_ROOT_TASK}
    VERBATIM)
  add_custom_target(bootfiles DEPENDS ${_staged})
  add_custom_target(bootcheck
    COMMAND "${PISTACHIO_BASH}" "${CMAKE_SOURCE_DIR}/scripts/check-bootfiles.sh" "${_boot}"
    DEPENDS bootfiles VERBATIM)
  set(_iso "${_boot}/pistachio.iso")
  add_custom_command(OUTPUT "${_iso}"
    COMMAND "${PISTACHIO_BASH}" "${CMAKE_SOURCE_DIR}/scripts/make-iso.sh"
      "${_boot}/kickstart" "${_boot}/x86-kernel" "${_boot}/sigma0" "${_boot}/roottask" "${_iso}"
    DEPENDS ${_staged} VERBATIM)
  add_custom_target(qemu-iso DEPENDS "${_iso}")
  add_custom_target(qemu
    COMMAND "${PISTACHIO_BASH}" "${CMAKE_SOURCE_DIR}/scripts/run-qemu.sh" "${_iso}"
    DEPENDS qemu-iso USES_TERMINAL VERBATIM)
  add_custom_target(qemu-gdb
    COMMAND "${PISTACHIO_BASH}" "${CMAKE_SOURCE_DIR}/scripts/run-qemu.sh" "${_iso}" --gdb
    DEPENDS qemu-iso USES_TERMINAL VERBATIM)
else()
  message(STATUS "x32 profile: standalone kernel build only; userland boot is x64")
endif()

enable_testing()
add_executable(udivdi3-test tests/udivdi3_test.c)
target_compile_definitions(udivdi3-test PRIVATE PISTACHIO_TEST_UDIVDI3)
add_test(NAME udivdi3 COMMAND udivdi3-test)
