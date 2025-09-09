package: OpenDataDetector
version: "%(tag_basename)s"
tag: "v4.0.2"
source: https://gitlab.cern.ch/acts/OpenDataDetector.git
requires:
  - "GCC-Toolchain:(?!osx)"
  - boost
  - ROOT
  - DD4Hep

build_requires:
  - CMake
  - bits-recipe-tools
---
#!/bin/bash -e
##############################
. $(bits-include CMakeRecipe)
##############################
MODULE_OPTIONS="--bin --lib"
##############################
function Configure() {
    cmake . -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} \
            -DCMAKE_INSTALL_PREFIX=$INSTALLROOT \
            -DCMAKE_CXX_STANDARD=${CXXSTD} \
            -DBUILD_TESTING=OFF \
            -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=${ENABLE_IPO}
}


