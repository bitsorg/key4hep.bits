package: defaults-release
version: v1
env:
  CXXFLAGS: "-fPIC -g -O2 -std=c++11"
  CFLAGS: "-fPIC -g -O2"
  CMAKE_BUILD_TYPE: "RELWITHDEBINFO"
  MACOSX_DEPLOYMENT_TARGET: '14.0'
  ENABLE_IPO: 'OFF'

system:
  sandbox_network: "off"
  build_oversubscribe: 1.25
  
variables:
  lcgversion: main

requires:
  lcg.bits

overrides:
  lcg.bits:
    tag: %(lcgversion)s
---
