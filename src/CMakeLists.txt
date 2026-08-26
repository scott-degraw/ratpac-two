###########################################################
# Go through each module and get their targets
#
# Adding a module here? It also needs an entry in RATPAC_MODULE_INCLUDE_DIRS
# immediately below, or nothing else can resolve its headers (see there for
# why) and rootcling won't find them either.

add_subdirectory(cmd)
add_subdirectory(core)
add_subdirectory(daq)
add_subdirectory(db)
add_subdirectory(fit)
add_subdirectory(gen)
add_subdirectory(geo)
add_subdirectory(io)
add_subdirectory(physics)
add_subdirectory(external)
add_subdirectory(util)
add_subdirectory(ds)
add_subdirectory(ratbase)

###########################################################
# Every module's include/ directory, collected onto ratpac_common (an
# INTERFACE target created in cmake/RatpacDependencies.cmake) rather than
# each module declaring only its own -- modules reference each other's
# headers directly (e.g. io includes geo's headers) and the 12-module
# strongly-connected component above makes target_link_libraries between
# modules impossible (CMake rejects link cycles among OBJECT libraries), so
# a shared leaf target is how every module ends up able to see every other
# module's headers. Verified safe: no header basename collides across any
# of the 13 modules.
#
# Kept in one place, here, right after the add_subdirectory() list above,
# so the two are visible together -- added a module above? Add it below too.
set(RATPAC_MODULE_INCLUDE_DIRS
    ${CMAKE_CURRENT_SOURCE_DIR}/cmd/include
    ${CMAKE_CURRENT_SOURCE_DIR}/core/include
    ${CMAKE_CURRENT_SOURCE_DIR}/daq/include
    ${CMAKE_CURRENT_SOURCE_DIR}/db/include
    ${CMAKE_CURRENT_SOURCE_DIR}/ds/include
    ${CMAKE_CURRENT_SOURCE_DIR}/fit/include
    ${CMAKE_CURRENT_SOURCE_DIR}/fit/mimir/include
    ${CMAKE_CURRENT_SOURCE_DIR}/gen/include
    ${CMAKE_CURRENT_SOURCE_DIR}/geo/include
    ${CMAKE_CURRENT_SOURCE_DIR}/io/include
    ${CMAKE_CURRENT_SOURCE_DIR}/physics/include
    ${CMAKE_CURRENT_SOURCE_DIR}/ratbase/include
    ${CMAKE_CURRENT_SOURCE_DIR}/util/include
    ${PROJECT_BINARY_DIR}/generated
)
foreach(_dir IN LISTS RATPAC_MODULE_INCLUDE_DIRS)
  target_include_directories(ratpac_common INTERFACE $<BUILD_INTERFACE:${_dir}>)
endforeach()

###########################################################
# Create Root Dictionary
#
# Subdirectories register their headers and LinkDef fragments via
# rat_dictionary_headers()/rat_dictionary_linkdef(); we generate the single
# RATDict here, once every subdirectory has contributed.
#
# root_generate_dictionary resolves the collected "as included" header names
# (e.g. RAT/DB.hh) via the *directory* INCLUDE_DIRECTORIES property
# (RootMacros.cmake: get_directory_property(incdirs INCLUDE_DIRECTORIES)),
# not via any target's usage requirements -- so the real per-module include
# dirs (the same list ratpac_common carries) must be set here too, the
# old-style way.
include_directories(${RATPAC_MODULE_INCLUDE_DIRS}
        ${CMAKE_CURRENT_SOURCE_DIR}/external/stlplus/include/stlplus
        ${CMAKE_CURRENT_SOURCE_DIR}/external/stlplus/include
)
get_property(RATDICT_HEADERS GLOBAL PROPERTY RATDICT_HEADERS)
rat_generate_linkdef(RATDICT_LINKDEF ${CMAKE_CURRENT_BINARY_DIR}/RATDictLinkDef.hh)
root_generate_dictionary(G__RATDict
        ${RATDICT_HEADERS}
        LINKDEF ${RATDICT_LINKDEF}
        # This DEPENDENCIES list is for compiling G__RATDict.cxx afterwards
        # (see root_generate_dictionary's other, target-property-based use of
        # DEPENDENCIES) -- ratpac_common covers the module include dirs and
        # stlplus, Ratpac::Geant4 covers headers like G4ThreeVector.hh (pulled
        # in by e.g. RAT/DS/NestedTubeInfo.hh).
        DEPENDENCIES ratpac_common Ratpac::Geant4
        OPTIONS -Wno-exceptions
)
add_library(RATDict OBJECT G__RATDict.cxx)
# G__RATDict.cxx #includes every collected RAT header, so it needs the same
# usage requirements those headers need to compile -- notably Geant4 (e.g.
# RAT/DS/NestedTubeInfo.hh pulls in G4ThreeVector.hh).
target_link_libraries(RATDict PUBLIC ratpac_common)

# Export the dictionary support files to the install tree.
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/libRATDict.rootmap
              ${CMAKE_CURRENT_BINARY_DIR}/libRATDict_rdict.pcm
        DESTINATION lib
)


###########################################################
# Create our libraries and executables

# The 13 RAT modules are one strongly-connected component (cmd<->core,
# core<->gen, core<->ds, ds<->io, core<->geo, db<->ratbase, ...), so they
# cannot be independently-linkable libraries -- this one list is both
# RATPAC's and RATEvent's real dependency closure and is kept in one place so
# the two can never drift apart the way they did before (RATEvent used to
# hand-maintain a separate, shorter list that fell out of sync with RATPAC's,
# which is what broke the macOS build). RATEvent linking this full closure,
# rather than a genuinely standalone subset, is addressed in a later stage of
# the CMake refactor.
set(RATPAC_MODULES
  cmd core daq db ds gen geo io fit physics ratbase stlplus cppflow util RATDict
)

# The module OBJECT/INTERFACE libraries are linked PRIVATE: their .o files
# are unconditionally folded into RATPAC.so/RATEvent.so's own link either
# way (that's not affected by the PUBLIC/PRIVATE keyword), but as internal
# implementation details they must not be PUBLIC -- install(EXPORT) below
# requires every PUBLIC-linked target to itself be part of an export set,
# and these 14 aren't (nor should they be: nothing downstream should need
# to know about "cmd" or "RATDict" as targets). Ratpac::* stay PUBLIC since
# they carry real usage requirements (Geant4/ROOT include dirs and
# definitions) that consumers linking Ratpac::RATPAC do need.
add_library(RATPAC SHARED)
target_link_libraries(RATPAC
  PUBLIC Ratpac::ROOT Ratpac::Geant4 Ratpac::CRY Ratpac::TensorFlow Ratpac::NLopt
  PRIVATE ${RATPAC_MODULES}
)
# Installed consumers (via find_package(Ratpac) + Ratpac::RATPAC) get the
# merged installed header tree here, same as the pre-refactor
# include_directories(@RATROOT@/include) in RatpacConfig.cmake.in. In-tree
# consumers (tools/rat and friends) link ratpac_common directly instead --
# see their CMakeLists.txt -- since the module object libraries above are
# PRIVATE and no longer propagate ratpac_common's BUILD_INTERFACE dirs.
target_include_directories(RATPAC PUBLIC $<INSTALL_INTERFACE:include>)
target_include_directories(RATPAC SYSTEM PUBLIC $<INSTALL_INTERFACE:include/stlplus>)

### Target: library for ROOT
add_library(RATEvent SHARED)
target_include_directories(RATEvent PUBLIC $<INSTALL_INTERFACE:include>)
target_include_directories(RATEvent SYSTEM PUBLIC $<INSTALL_INTERFACE:include/stlplus>)
target_link_libraries(RATEvent
  PUBLIC Ratpac::ROOT Ratpac::Geant4 Ratpac::CRY Ratpac::TensorFlow Ratpac::NLopt
  PRIVATE ${RATPAC_MODULES}
)

# This copies the root dict files to <build>/lib
add_custom_command(TARGET RATPAC POST_BUILD
   COMMAND ${CMAKE_COMMAND} -E copy
       ${CMAKE_CURRENT_BINARY_DIR}/libRATDict_rdict.pcm
       ${CMAKE_CURRENT_BINARY_DIR}/libRATDict.rootmap
       ${PROJECT_BINARY_DIR}/lib
)

# This copies the root dict files to <build>/bin
add_custom_command(TARGET RATPAC POST_BUILD
   COMMAND ${CMAKE_COMMAND} -E copy
       ${CMAKE_CURRENT_BINARY_DIR}/libRATDict_rdict.pcm
       ${CMAKE_CURRENT_BINARY_DIR}/libRATDict.rootmap
       ${PROJECT_BINARY_DIR}/bin
)

# Native suffix (.dylib on macOS, .so on Linux) -- nothing hardcodes ".so"
# anymore: RatpacConfig.cmake.in reads Ratpac_LIBRARIES off the real imported
# target's LOCATION property instead of a literal path, gSystem->Load("libRATPAC")
# in rootinit.C is extension-agnostic, and python/rat/__init__.py already
# tries .so then falls back to .dylib.
set_target_properties(RATPAC RATEvent
    PROPERTIES
       ARCHIVE_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/lib
       LIBRARY_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/lib
)

install(TARGETS RATPAC RATEvent
        EXPORT RatpacTargets
        RUNTIME DESTINATION bin
        LIBRARY DESTINATION lib
        ARCHIVE DESTINATION lib
)

### Headers are installed per-module (install(DIRECTORY include/ DESTINATION
### include) in each module's own CMakeLists.txt) rather than as one global
### directory copy -- there is no longer a single merged build/include
### directory to copy from; see the CMake refactor plan's "Real header
### staging" section.
