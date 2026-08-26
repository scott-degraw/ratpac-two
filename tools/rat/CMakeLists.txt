############################################################
# CMakeLists for rat tool

add_executable(rat rat.cpp)
# ratpac_common for RAT/AnyParse.hh and friends: RATPAC's own module object
# libraries (which carry those include dirs) are linked PRIVATE now that
# RATPAC is an install(EXPORT)-ed target, so they no longer propagate here.
target_link_libraries(rat PUBLIC RATPAC ratpac_common)

install(TARGETS rat
        RUNTIME DESTINATION bin
)
