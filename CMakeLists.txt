cmake_minimum_required(VERSION 3.16...3.31)
include(CMakePackageConfigHelpers)
# Automatically get version of git tags.
execute_process(
    COMMAND git --git-dir=${CMAKE_SOURCE_DIR}/.git describe --tags --always
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    OUTPUT_VARIABLE RATVERSION
    ERROR_QUIET
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

execute_process(
    COMMAND git --git-dir=${CMAKE_SOURCE_DIR}/.git describe --tags --abbrev=0
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    OUTPUT_VARIABLE RATVERSION_SEMVERS
    ERROR_QUIET
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
if(NOT RATVERSION_SEMVERS)
  set(RATVERSION_SEMVERS 4.2.0)
endif()

project(ratpac
  DESCRIPTION "RAT, Plus Additional Code, Version 2"
  HOMEPAGE_URL "https://ratpac.readthedocs.io/en/latest/"
  VERSION ${RATVERSION_SEMVERS}
  LANGUAGES C CXX
)

# Fallback version:
if(NOT RATVERSION)
  set(RATVERSION ${PROJECT_VERSION})
endif()

###########################################################
# Require out-of-source builds
file(TO_CMAKE_PATH "${PROJECT_BINARY_DIR}/CMakeLists.txt" LOC_PATH)
if(EXISTS "${LOC_PATH}")
  message(FATAL_ERROR "You cannot build in a source directory (or any directory with a CMakeLists.txt file). Please make a build subdirectory. Feel free to remove CMakeCache.txt and CMakeFiles.")
endif()

# Use RPATH for install
set(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/lib")

# add the automatically determined parts of the RPATH
# which point to directories outside the build tree to the install RPATH
set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)

# Automatically generate compile_commands.json
set(CMAKE_EXPORT_COMPILE_COMMANDS TRUE)
add_custom_target(
    copy-compile-commands ALL
    ${CMAKE_COMMAND} -E copy_if_different
        ${CMAKE_BINARY_DIR}/compile_commands.json
        ${CMAKE_CURRENT_LIST_DIR}
)

###########################################################
# Set default build type
set(default_build_type "RelWithDebInfo")
#set(CMAKE_BUILD_TYPE Debug)
#set(CMAKE_CXX_FLAGS -pg)
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  message(STATUS "Setting build type to '${default_build_type}' as none was specified.")
  set(CMAKE_BUILD_TYPE "${default_build_type}" CACHE
      STRING "Choose the type of build." FORCE
  )
  # Set the possible values of build type for cmake-gui
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
    "Debug" "Release" "MinSizeRel" "RelWithDebInfo"
  )
endif()
add_compile_options(-Wall)
# Not turning on errors yet to ease transition
# add_compile_options(-Werror)

###########################################################
# Set CMAKE standards
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

###########################################################
# Options
option(RATPAC_ROOT "build bootstrapped root executable" ON)
option(RATPAC_RAT "build rat executable" ON)

###########################################################
# External libraries and dependencies: find them and wrap them in
# target-based usage requirements (ratpac_common, Ratpac::Geant4,
# Ratpac::ROOT, Ratpac::NLopt, Ratpac::TensorFlow, Ratpac::CRY)
include(${CMAKE_SOURCE_DIR}/cmake/RatpacDependencies.cmake)

###########################################################
# Configure header with our version information
#
# Generated into the build tree, not src/core/include/RAT/ -- a generated
# file doesn't belong in the source tree (it used to land there, which meant
# every fresh configure dirtied `git status`). ${PROJECT_BINARY_DIR}/generated
# is on ratpac_common's include path (cmake/RatpacDependencies.cmake), so
# `#include <RAT/Config.hh>` still resolves the same as before.
configure_file(${CMAKE_SOURCE_DIR}/config/Config.hh.in
  ${PROJECT_BINARY_DIR}/generated/RAT/Config.hh
  @ONLY NEWLINE_STYLE UNIX
)
install(FILES ${PROJECT_BINARY_DIR}/generated/RAT/Config.hh DESTINATION include/RAT)

# Configure local scripts
set(RATROOT ${CMAKE_INSTALL_PREFIX})
set(RATSHARE ${PROJECT_SOURCE_DIR})
configure_file(${CMAKE_SOURCE_DIR}/config/ratpac.sh.in
  ${PROJECT_SOURCE_DIR}/ratpac.sh
  @ONLY NEWLINE_STYLE UNIX
)
configure_file(${CMAKE_SOURCE_DIR}/config/ratpac.csh.in
  ${PROJECT_SOURCE_DIR}/ratpac.csh
  @ONLY NEWLINE_STYLE UNIX
)
#configure_file(${CMAKE_SOURCE_DIR}/config/RatpacConfig.cmake.in
#  ${PROJECT_SOURCE_DIR}/RatpacConfig.cmake
#  @ONLY NEWLINE_STYLE UNIX)

###########################################################
# Helper functions
include(${CMAKE_SOURCE_DIR}/cmake/RATDictionary.cmake)

###########################################################
# Compile our libraries and executables

add_subdirectory(src)
add_subdirectory(tools)

###########################################################
# Installation

# Configure global scripts
set(RATSHARE ${CMAKE_INSTALL_PREFIX}/share/RAT)
configure_file(${CMAKE_SOURCE_DIR}/config/ratpac.sh.in
  ${PROJECT_BINARY_DIR}/bin/ratpac.sh
  @ONLY NEWLINE_STYLE UNIX
)
configure_file(${CMAKE_SOURCE_DIR}/config/ratpac.csh.in
  ${PROJECT_BINARY_DIR}/bin/ratpac.csh
  @ONLY NEWLINE_STYLE UNIX
)
configure_package_config_file(${CMAKE_SOURCE_DIR}/config/RatpacConfig.cmake.in
  ${PROJECT_BINARY_DIR}/cmake/RatpacConfig.cmake
  INSTALL_DESTINATION cmake
  NO_SET_AND_CHECK_MACRO
)
write_basic_package_version_file(
  "${PROJECT_BINARY_DIR}/cmake/RatpacConfigVersion.cmake"
  VERSION ${PROJECT_VERSION}
  COMPATIBILITY SameMinorVersion
)
# Same destination as RatpacConfig.cmake below (DESTINATION cmake, not the
# more conventional lib/cmake/Ratpac) so the existing include(RatpacTargets.cmake)
# via CMAKE_CURRENT_LIST_DIR in RatpacConfig.cmake.in finds it, and so
# whatever discovers today's flat cmake/RatpacConfig.cmake keeps working
# unchanged for existing consumers (e.g. RatpacExperiment).
install(EXPORT RatpacTargets NAMESPACE Ratpac:: DESTINATION cmake)

# Install the data files
install(DIRECTORY ratdb/ DESTINATION ${RATSHARE}/ratdb
  PATTERN "ratdb/*"
)

install(DIRECTORY models/ DESTINATION ${RATSHARE}/models
  PATTERN "models/*"
)

# Install the python files
install(DIRECTORY python/ DESTINATION ${RATSHARE}/python
  PATTERN "python/*"
)

# Install rattest executable
install(PROGRAMS python/rattest.py DESTINATION bin RENAME rattest)

# Install the macro files
install(DIRECTORY macros/ DESTINATION ${RATSHARE}/macros
  PATTERN "macros/*"
)

# Install the doc files
install(DIRECTORY doc/ DESTINATION ${RATSHARE}/doc
  PATTERN "doc/*"
)

# Install env files
install(FILES ${PROJECT_BINARY_DIR}/bin/ratpac.sh
  ${PROJECT_BINARY_DIR}/bin/ratpac.csh
  DESTINATION bin
)

install(FILES ${PROJECT_BINARY_DIR}/cmake/RatpacConfig.cmake
  DESTINATION cmake
)

install(FILES ${PROJECT_BINARY_DIR}/cmake/RatpacConfigVersion.cmake
  DESTINATION cmake
)
