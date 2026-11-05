set(_user "${CMAKE_SOURCE_DIR}/user")
set(_out "${CMAKE_BINARY_DIR}/user")

file(MAKE_DIRECTORY "${_out}/include")
file(WRITE "${_out}/include/config.h" "/* CMake-generated L4 userland settings. */\n#ifndef L4_USER_MODERN_CONFIG_H\n#define L4_USER_MODERN_CONFIG_H\n#define CONFIG_COMPORT ${PISTACHIO_COMPORT}\n#define CONFIG_COMSPEED ${PISTACHIO_COMSPEED}\n#endif\n")

include ("${CMAKE_CURRENT_LIST_DIR}/user.cmake")

add_subdirectory("${_user}/lib" "${CMAKE_CURRENT_BINARY_DIR}/lib")
add_subdirectory("${_user}/serv" "${CMAKE_CURRENT_BINARY_DIR}/serv")
add_subdirectory("${_user}/util" "${CMAKE_CURRENT_BINARY_DIR}/util")
add_subdirectory("${_user}/apps" "${CMAKE_CURRENT_BINARY_DIR}/apps")

add_custom_target(userland DEPENDS kickstart sigma0 "${PISTACHIO_ROOT_TASK}")