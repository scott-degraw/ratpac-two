# Finds every third-party dependency RATPAC needs and wraps it in a
# target-based usage requirement -- one section per dependency below (find it,
# then wrap it), plus ratpac_common at the end, the usage-requirement target
# every RAT module links for its baseline compile/include requirements.

###########################################################
# ROOT
if(ROOT_DIR)
find_package(ROOT NO_DEFAULT_PATH CONFIG REQUIRED COMPONENTS Minuit2 ROOTTPython MathMore)
else()
find_package(ROOT CONFIG REQUIRED COMPONENTS Minuit2 ROOTTPython MathMore)
endif()
include(${ROOT_USE_FILE})

# Unlike Geant4, this ROOT install does define namespaced imported targets
# (ROOT::Core, ROOT::Tree, ...), one per component. Aggregate exactly the
# components ROOT_LIBRARIES was built from (see ROOTConfig.cmake) into a single
# Ratpac::ROOT target so modules link one thing instead of the bare
# ${ROOT_LIBRARIES} path list.
set(RATPAC_ROOT_COMPONENTS
    Core Imt RIO Net Hist Graf Graf3d Gpad ROOTDataFrame Tree TreePlayer Rint
    Postscript Matrix Physics MathCore Thread MultiProc ROOTVecOps
    Minuit2 ROOTTPython MathMore
)
add_library(Ratpac::ROOT INTERFACE IMPORTED)
foreach(_comp IN LISTS RATPAC_ROOT_COMPONENTS)
  if(TARGET ROOT::${_comp})
    target_link_libraries(Ratpac::ROOT INTERFACE ROOT::${_comp})
  endif()
endforeach()

###########################################################
# Geant4
#
# Geant4_LIBRARIES is fully recomputed (not accumulated) by Geant4Config.cmake
# on every find_package(Geant4 ...) call -- splitting this into a plain
# REQUIRED call followed by a separate OPTIONAL_COMPONENTS call only works if
# the OPTIONAL_COMPONENTS call comes last, since whichever call runs last wins
# outright. One call avoids that order dependency entirely.
find_package(Geant4 11.4 REQUIRED OPTIONAL_COMPONENTS vis_all ui_all)
include(${Geant4_USE_FILE})

# This Geant4 install's Geant4Config.cmake defines no imported targets at all
# (verified: zero add_library() calls in it) -- only the classic
# Geant4_LIBRARIES / Geant4_INCLUDE_DIRS / Geant4_DEFINITIONS variables. Wrap
# them in one IMPORTED INTERFACE target so consumers get a target to link
# instead of a bare variable, and so the include dirs/definitions travel with
# it instead of needing directory-scoped include_directories().
# Geant4_INCLUDE_DIRS does not always cover CLHEP/XercesC (verified: on this
# machine CLHEP_INCLUDE_DIRS is empty -- Geant4's builtin CLHEP headers are
# already under Geant4_INCLUDE_DIRS -- but XercesC_INCLUDE_DIRS is a separate
# path, /opt/homebrew/include, not contained in Geant4_INCLUDE_DIRS). Fold
# both in so Ratpac::Geant4 is a complete replacement for the three
# directory-scoped include_directories() calls this replaces.
add_library(Ratpac::Geant4 INTERFACE IMPORTED)
target_link_libraries(Ratpac::Geant4 INTERFACE ${Geant4_LIBRARIES})
target_include_directories(Ratpac::Geant4 SYSTEM INTERFACE
        ${Geant4_INCLUDE_DIRS} ${CLHEP_INCLUDE_DIRS} ${XercesC_INCLUDE_DIRS}
)
target_compile_definitions(Ratpac::Geant4 INTERFACE ${Geant4_DEFINITIONS})

###########################################################
# Threads
find_package(Threads REQUIRED)
# Threads::Threads is already a real imported target -- nothing to wrap.

###########################################################
# CURL
#
# db/src/HTTPDownloader.cc calls libcurl directly. This was previously
# unlisted anywhere and only "worked" because the linker could resolve it
# implicitly (macOS: libcurl.tbd is in the default SDK search path; Linux:
# tolerated lazily). Make it an explicit, portable dependency.
find_package(CURL REQUIRED)
# CURL::libcurl is already a real imported target -- nothing to wrap.

###########################################################
# FFTW3
find_package(PkgConfig REQUIRED)
pkg_check_modules(FFTW3 REQUIRED IMPORTED_TARGET fftw3)
if (NOT TARGET FFTW3::fftw3)
  # pkg_check_modules(... IMPORTED_TARGET) already populates
  # PkgConfig::FFTW3's INTERFACE_INCLUDE_DIRECTORIES from FFTW3_INCLUDE_DIRS,
  # and that propagates through the alias -- no separate include_directories()
  # needed (an ALIAS target can't be the target of target_include_directories
  # anyway).
  add_library(FFTW3::fftw3 ALIAS PkgConfig::FFTW3)
endif()

###########################################################
# NLopt
#
# Optional: found via find_library()/find_path() since it ships no CMake
# config package, and may be absent (NLOPT_LIBRARIES ends up "-NOTFOUND").
# NLOPT_Enabled feeds config/Config.hh.in (a compiled-in feature flag) as well
# as the target-wrapping below. The target is defined unconditionally, empty
# when the dependency is missing, so consumers can link it without repeating
# the NLOPT_Enabled guard themselves; the guard still applies to compiling
# the sources that need the header.
set(NLOPT_Enabled 0)
find_library(NLOPT_LIBRARIES nlopt)
find_path(NLOPT_INCLUDE_DIRS nlopt.hpp)
if(NLOPT_LIBRARIES AND NLOPT_INCLUDE_DIRS)
    message(STATUS "Compiling with NLOPT")
    set(NLOPT_Enabled 1)
else()
    message(WARNING "NLOPT Not Found")
    set(NLOPT_LIBRARIES "")
    set(NLOPT_INCLUDE_DIRS "")
endif()

add_library(Ratpac::NLopt INTERFACE IMPORTED)
if(NLOPT_Enabled)
  target_link_libraries(Ratpac::NLopt INTERFACE ${NLOPT_LIBRARIES})
  target_include_directories(Ratpac::NLopt SYSTEM INTERFACE ${NLOPT_INCLUDE_DIRS})
endif()

###########################################################
# TensorFlow
#
# Optional, same pattern as NLopt above: found via find_library()/find_path(),
# may be absent, TENSORFLOW_Enabled feeds config/Config.hh.in, target defined
# unconditionally.
set(TENSORFLOW_Enabled 0)
find_library(TENSORFLOW_LIBRARIES tensorflow)
find_path(TENSORFLOW_INCLUDE_DIRS tensorflow/c/c_api.h)
if(TENSORFLOW_LIBRARIES AND TENSORFLOW_INCLUDE_DIRS)
  message(STATUS "Compiling with Tensorflow")
  set(TENSORFLOW_Enabled 1)
else()
  message(WARNING "Tensorflow Not Found")
  set(TENSORFLOW_LIBRARIES "")
  set(TENSORFLOW_INCLUDE_DIRS "")
endif()

add_library(Ratpac::TensorFlow INTERFACE IMPORTED)
if(TENSORFLOW_Enabled)
  target_link_libraries(Ratpac::TensorFlow INTERFACE ${TENSORFLOW_LIBRARIES})
  target_include_directories(Ratpac::TensorFlow SYSTEM INTERFACE ${TENSORFLOW_INCLUDE_DIRS})
endif()

###########################################################
# CRY
#
# Optional, enabled only via the $CRYLIB environment variable -- CRY ships no
# CMake config package and isn't discoverable via find_library(), so its
# location can only come from the user pointing at it directly. Same
# unconditional-target pattern as NLopt/TensorFlow above.
set(CRY_Enabled 0)
if(DEFINED ENV{CRYLIB})
  message(STATUS "Compiling with CRY enabled")
  set(CRY_Enabled 1)
  set(CRYLIBDIR $ENV{CRYLIB})
  set(CRYINCLUDE $ENV{CRYINCLUDE})
  set(CRYDATA $ENV{CRYDATA})
  set(CRY_LIBRARIES CRY)
endif()

add_library(Ratpac::CRY INTERFACE IMPORTED)
if(CRY_Enabled)
  target_link_libraries(Ratpac::CRY INTERFACE ${CRY_LIBRARIES})
  target_include_directories(Ratpac::CRY SYSTEM INTERFACE ${CRYINCLUDE})
  target_link_directories(Ratpac::CRY INTERFACE ${CRYLIBDIR})
endif()

###########################################################
# ratpac_common
#
# Baseline usage requirements every RAT module needs: C++17, the collected
# header tree, Geant4, and ROOT. Third-party deps used by only some modules
# (FFTW3::fftw3, Ratpac::NLopt, Ratpac::TensorFlow, Ratpac::CRY, stlplus,
# cppflow) are linked per-module on top of this, not here.
add_library(ratpac_common INTERFACE)
target_compile_features(ratpac_common INTERFACE cxx_std_17)
target_link_libraries(ratpac_common INTERFACE Ratpac::Geant4 Ratpac::ROOT)
target_include_directories(ratpac_common INTERFACE $<INSTALL_INTERFACE:include>)

# Every module's #include <RAT/Foo.hh> resolves via one flat search list
# (each module's own include/ directory), not a merged directory -- see the
# "Real header staging" section of the CMake refactor plan for why: modules
# reference each other's headers directly (e.g. io includes geo's headers),
# and putting per-module include dirs on the module's own target instead of
# here would need target_link_libraries between modules, which is impossible
# given the 12-module strongly-connected component (CMake rejects
# dependency cycles among OBJECT libraries). Putting them all on this shared
# leaf target instead avoids the cycle. Safe because there isn't a single
# header basename collision across all 13 modules (verified).
#
# The list itself (RATPAC_MODULE_INCLUDE_DIRS) is NOT here -- it lives in
# src/CMakeLists.txt, right next to the add_subdirectory() calls that add
# each module, specifically so adding a new module is a one-file edit: both
# lists are visible at once, and each has a comment pointing at the other.
# It's populated onto ratpac_common (this target, already created above) from
# there via target_include_directories(ratpac_common INTERFACE ...).

# stlplus and cppflow keep their own SYSTEM include dirs (declared on their
# own targets in src/external/*/CMakeLists.txt); ratpac_common only needs to
# see stlplus's headers because most modules include them without linking
# the stlplus target directly. Two different forms are used: bare
# (<dprintf.hpp>, inside stlplus's own sources) and namespaced
# (<stlplus/string_utilities.hpp>, e.g. io/src/OutNtupleProc.cc) -- so both
# .../stlplus/include/stlplus and its parent .../stlplus/include are needed.
target_include_directories(ratpac_common SYSTEM INTERFACE
        $<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}/src/external/stlplus/include/stlplus>
        $<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}/src/external/stlplus/include>
)
