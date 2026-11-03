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

# The key4hep CVMFS namespace and layout are in cvmfs.yaml.
---
