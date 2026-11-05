add_subdirectory(bench/pingpong)
# add_subdirectory(l4test)

foreach(_app IN ITEMS helloworld)
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${_app}/CMakeLists.txt")
        add_subdirectory("${_app}")
    endif()
endforeach()
