############################################################
# CMakeLists for rat tool

add_executable(ntuple ntuple.cpp)
# ratpac_common for RAT/AnyParse.hh and friends: RATPAC's own module object
# libraries (which carry those include dirs) are linked PRIVATE now that
# RATPAC is an install(EXPORT)-ed target, so they no longer propagate here.
target_link_libraries(ntuple PUBLIC RATPAC ratpac_common)
add_dependencies(ntuple RATPAC)

install(TARGETS ntuple
        RUNTIME DESTINATION bin
)
