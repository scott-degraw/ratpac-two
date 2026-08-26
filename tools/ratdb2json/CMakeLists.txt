############################################################
# CMakeLists for rat tool

add_executable(ratdb2json ratdb2json.cpp)
# ratpac_common for RAT/AnyParse.hh and friends: RATPAC's own module object
# libraries (which carry those include dirs) are linked PRIVATE now that
# RATPAC is an install(EXPORT)-ed target, so they no longer propagate here.
target_link_libraries(ratdb2json PUBLIC RATPAC ratpac_common)
add_dependencies(ratdb2json RATPAC)

install(TARGETS ratdb2json
        RUNTIME DESTINATION bin
)
