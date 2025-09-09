package: OpenDataDetector
version: "%(tag_basename)s"
tag: "v4.0.3"
source: https://github.com/AIDASoft/podio
requires:
  - "GCC-Toolchain:(?!osx)"
  - BOOST
  - ROOT
  - DD4Hep
  
build_requires:
  - CMake
  - bits-recipe-tools
---
#!/bin/bash -e
function Configure() {
    cmake . -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
            -DCMAKE_INSTALL_PREFIX=<INSTALL_DIR>
            -DCMAKE_CXX_STANDARD=${CMAKE_CXX_STANDARD}
            -DBUILD_TESTING=OFF
            -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=${ENABLE_IPO}
}
  
 


