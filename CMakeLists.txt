cmake_minimum_required(VERSION 3.22)
project(pixel-bloom-game VERSION 0.1.0 LANGUAGES C)

# Set C Standard (11 is multithread support - can be useful at multiplayer)
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)


# Set options for build types
set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release" "MinSizeRel" "RelWithDebInfo")

set(RAYLIB_BUILD_EXAMPLES OFF CACHE BOOL "Don't build raylib examples" FORCE)

# Dependencies
# set(RAYLIB_VERSION 5.5) # Change this to the version you want to use
set(RAYLIB_VERSION "master")
include(FetchContent)
# check if RAYLIB_VERSION is a number
if(RAYLIB_VERSION MATCHES "^[0-9.]+$")
    find_package(raylib ${RAYLIB_VERSION} QUIET) # QUIET or REQUIRED

    if (NOT raylib_FOUND) # If there's none, fetch and build raylib
        FetchContent_Declare(
            raylib
            DOWNLOAD_EXTRACT_TIMESTAMP OFF
            URL https://github.com/raysan5/raylib/archive/refs/tags/${RAYLIB_VERSION}.tar.gz
        )
        FetchContent_GetProperties(raylib)
        if (NOT raylib_POPULATED) # Have we downloaded raylib yet?
            set(FETCHCONTENT_QUIET NO)
            FetchContent_MakeAvailable(raylib)
            set(BUILD_EXAMPLES OFF CACHE BOOL "" FORCE) # don't build the supplied examples
        endif()

    endif()
else()
    # download the latest version of raylib
    FetchContent_Declare(
        raylib
        GIT_REPOSITORY https://github.com/raysan5/raylib.git
        GIT_TAG ${RAYLIB_VERSION} 
    )
    FetchContent_GetProperties(raylib)
    set(FETCHCONTENT_QUIET NO)
    FetchContent_MakeAvailable(raylib)
    set(BUILD_EXAMPLES OFF CACHE BOOL "" FORCE) # don't build the supplied examples
endif()    

add_executable(${PROJECT_NAME} src/main.c)
if ("${PLATFORM}" STREQUAL "Web")
    # Tell Emscripten to build an example.html file.
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Os")    
    # Since WASM is used, ALLOW_MEMORY_GROWTH has no extra overheads
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -s WASM=1 -s ASYNCIFY -s ALLOW_MEMORY_GROWTH=1 --shell-file ${CMAKE_SOURCE_DIR}/src/minshell.html")
    set(CMAKE_EXECUTABLE_SUFFIX ".html")
    #DEPENDS ${PROJECT_NAME}
else()
    add_custom_command(
       TARGET ${PROJECT_NAME} POST_BUILD
       COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_SOURCE_DIR}/resources $<TARGET_FILE_DIR:${PROJECT_NAME}>/resources
    )
    #DEPENDS ${PROJECT_NAME}
endif()
target_link_libraries(${PROJECT_NAME} raylib)

# Detect the compiler
if (CMAKE_C_COMPILER_ID STREQUAL "GNU")
    # GCC
    target_compile_options(${PROJECT_NAME} PRIVATE -Wall -Werror)
elseif (CMAKE_C_COMPILER_ID STREQUAL "Clang")
    # Clang
    target_compile_options(${PROJECT_NAME} PRIVATE -Wall -Werror)
elseif (CMAKE_C_COMPILER_ID STREQUAL "MSVC")
    # Do not use /W4 for now, as it is too strict and generates too many warnings
    # target_compile_options(${PROJECT_NAME} PRIVATE /W4 /WX) 
elseif (CMAKE_C_COMPILER_ID STREQUAL "Intel")
  #Intel Compiler
  target_compile_options(${PROJECT_NAME} PRIVATE -Wall -Werror)
endif()

set_target_properties(${PROJECT_NAME} PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/${PROJECT_NAME})

set_property(TARGET ${PROJECT_NAME} PROPERTY VS_DEBUGGER_WORKING_DIRECTORY $<TARGET_FILE_DIR:${PROJECT_NAME}>)

# Checks if OSX and links appropriate frameworks (Only required on MacOS)
if (APPLE)
    target_link_libraries(${PROJECT_NAME} "-framework IOKit")
    target_link_libraries(${PROJECT_NAME} "-framework Cocoa")
    target_link_libraries(${PROJECT_NAME} "-framework OpenGL")
endif()