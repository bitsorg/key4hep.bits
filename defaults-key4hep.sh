package: defaults-key4hep
version: v1
# key4hep group overlay — compose with:  --defaults key4hep[::gcc15::opt]
# Inherits the shared build env + package_family + release/lcg.bits tag wiring from
# stacks.bits (-> lcg.bits recipe pool); adds only the key4hep CVMFS namespace.
requires:
  - stacks.bits

# key4hep CVMFS namespace + layout (system: is NOT hashed -> never affects reuse).
# Policy knobs (sandbox_network/build_oversubscribe/source_mode) inherit from stacks.
system:
  prefix:                     "/cvmfs/bits.cern.ch/key4hep/releases"
  cvmfs_user_prefix:          "/cvmfs/bits.cern.ch/key4hep/user"
  cvmfs_releases_template:    "{prefix}/{pkg}/{tag}/{platform}"
  cvmfs_modules_template:     "{prefix}/{platform}/Modules/modulefiles/{pkg}"
  cvmfs_shared_path_template: "{prefix}/noarch/{pkg}/{tag}"
---
