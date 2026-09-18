package: defaults-release
version: v1
env:
  # No CXXFLAGS/-std here: the C++ standard is owned by the compiler-axis defaults
  # (stacks.bits/defaults-gccNN, defaults-clang), not this base profile. The old
  # -std=c++11 pin was far too low for modern key4hep/ROOT.
  CFLAGS: "-fPIC -g -O2"
  CMAKE_BUILD_TYPE: "RELWITHDEBINFO"
  MACOSX_DEPLOYMENT_TARGET: '14.0'
  ENABLE_IPO: 'OFF'

system:
  sandbox_network: "off"
  build_oversubscribe: 1.25
  # CVMFS path templates
  # {prefix} is the releases ROOT (auth boundary). bits-console (ui-config.yaml:
  # cvmfs_prefix) injects the authoritative value, which WINS; the value below MUST
  # match it (kept in sync by bits-admin PR) or an injected build refuses to publish.
  # It lets local `bits build` (no injection) work and is a checked declaration.
  prefix:                     "/cvmfs/sft-nightlies-test.cern.ch/key4hep/releases"
  cvmfs_user_prefix:          "/cvmfs/sft-nightlies-test.cern.ch/key4hep/user"  # sibling of releases, not {prefix}/user
  cvmfs_releases_template:        "{prefix}/{pkg}/{tag}/{platform}"
  cvmfs_modules_template:     "{prefix}/{platform}/Modules/modulefiles/{pkg}"
  cvmfs_shared_path_template: "{prefix}/noarch/{pkg}/{tag}"

variables:
  # THE release label - single source of truth for BOTH the lcg.bits recipe branch
  # (the override below feeds it as %(release)s) and the CVMFS {release} path slot.
  # `main` is the trunk sentinel: `bits` resolves the effective release as
  #   explicit non-trunk release: (dev3/dev4/LCG_NNN) -> working-dir branch -> main
  # so this default reproduces the old behaviour - build lcg.bits `main`, and,
  # because a `main` release collapses the {release}/ segment out, publish with no
  # release level in the path. Check out a recipe branch and the build tracks the
  # matching lcg.bits branch and publishes under /releases/<branch>/…; set an
  # explicit release: (dev3/dev4/a tag) to name a dedicated one. The value that is
  # in effect must exist as an lcg.bits branch - that is the recipe pool.
  release: main

requires:
  - lcg.bits

overrides:
  lcg.bits:
    tag: "%(release)s"
---
