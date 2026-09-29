package: defaults-key4hep
version: v1
# key4hep group overlay — compose with:  --defaults key4hep[::gcc15::opt]
# Inherits the shared build env + package_family from stacks.bits (-> lcg.bits
# recipe pool) The release comes from the command line (--set release=LCG_110)
# `main` is  only the default.
variables:
  release: "main"

requires:
  - stacks.bits

overrides:
  lcg.bits:
    tag: "%(release)s"
  stacks.bits:
    tag: "%(release)s"

# key4hep CVMFS namespace + layout: 
# Policy knobs (sandbox_network/build_oversubscribe/source_mode) inherit from stacks.
# ALICE-style tree: packages published once under the build arch (platform-first
# keeps each platform's catalogs apart), modulefiles beside them.
# A release is a view of symlinks to the packages, created only
# when asked for (bits cvmfs publish --release-view / console option).
system:
  prefix:                     "/cvmfs/bits.cern.ch/key4hep"
  cvmfs_user_prefix:          "{prefix}/user"
  cvmfs_packages_template:    "{prefix}/{arch}/Packages/{pkg}/{tag}"
  cvmfs_modules_template:     "{prefix}/{arch}/Modules/modulefiles/{pkg}"
  cvmfs_shared_path_template: "{prefix}/noarch/{pkg}/{tag}"
  cvmfs_releases_template:    "{prefix}/releases/{release}/{family}{pkg}/{version}/{arch}"
---
