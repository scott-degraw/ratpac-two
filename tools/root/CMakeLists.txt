############################################################
# CMakeLists for root tool

add_executable(root root.cc)
# root.cc includes RAT/Config.hh; ratpac_common carries the real per-module
# include dirs (see cmake/RatpacDependencies.cmake) now that there's no
# merged build/include tree to point at.
target_link_libraries(root PUBLIC ratpac_common Ratpac::ROOT Threads::Threads)
# Add dependency because we're not linking, but the root.cc adds it dynamically
add_dependencies(root RATPAC)

file(COPY rootinit.C DESTINATION ${PROJECT_BINARY_DIR}/src)

# Make sure we don't overwrite original root
if(EXISTS "${CMAKE_INSTALL_PREFIX}/bin/root" AND RATPAC_ROOT)
       message(WARNING "${CMAKE_INSTALL_PREFIX}/bin/root already exists. If you wish to install to this directory you must remove or rename this file.")
endif()

install(TARGETS root
        RUNTIME DESTINATION bin
)
install(FILES rootinit.C
       DESTINATION src
)
