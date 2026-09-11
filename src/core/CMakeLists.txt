###########################################################
# CMakeLists for core module

add_library(core OBJECT
        src/Log.cc
        src/GLG4HitPhoton.cc
        src/GLG4HitPMT.cc
        src/GLG4SteppingAction.cc
        src/PythonProc.cc
        src/ProcBlock.cc
        src/ProducerBlock.cc
        src/RunManager.cc
        src/RatRunManager.cc
        src/CountProc.cc
        src/PruneProc.cc
        src/Gsim.cc
        src/ConstructUserProc.cc
        src/GLG4VisManager.cc
        src/GLG4VEventAction.cc
        src/StackingAction.cc
        src/Producer.cc
        src/Trajectory.cc
        src/Processor.cc
        src/SignalHandler.cc
        src/TrackInfo.cc
        src/TrackCompactor.cc
        src/Log.cc
        src/GLG4HitPMTCollection.cc)

# ratpac_common carries Ratpac::Geant4, which propagates Geant4_DEFINITIONS
# (e.g. G4VIS_USE_OPENGLQT) via target_compile_definitions -- so the
# G4VIS_USE_* #ifdef blocks in GLG4VisManager.cc get enabled for real. (The
# previous `target_link_libraries(core PUBLIC ${Geant4_LIBRARIES})` here could
# not actually do this: Geant4_LIBRARIES is a list of bare .dylib paths, not
# targets, so it carries no INTERFACE_COMPILE_DEFINITIONS to propagate.)
target_link_libraries(core PUBLIC ratpac_common stlplus)

# Copy our headers when installing
install(DIRECTORY include/ DESTINATION include)

# Contribute this module's headers and LinkDef fragment to the RAT ROOT
# dictionary (RATDict).
rat_dictionary_linkdef(RAT/core/LinkDef.hh)
rat_dictionary_headers(RAT/Log.hh)
