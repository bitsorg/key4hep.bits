# key4hep.bits

Defaults and the stack meta-package for building the **Key4hep** software stack with
[bits](https://github.com/bitsorg/bits). The repository contains no package recipes
of its own. The packages (podio, EDM4hep, DD4hep, Gaudi, ACTS, the `k4*` framework,
the iLCSoft/Marlin family and the FCC packages) all come from the
[lcg.bits](https://github.com/bitsorg/lcg.bits) recipe pool. `key4hep.bits` adds two
things: the `key4hep` meta-package, which names the whole stack, and the Key4hep CVMFS
layout in `defaults-key4hep.sh`. That file requires
[stacks.bits](https://github.com/bitsorg/stacks.bits), which provides the shared
`release` base and the compiler and build-type profiles, and `stacks.bits` in turn
requires `lcg.bits`. bits fetches both automatically through the
[bits-providers](https://github.com/bitsorg/bits-providers) registry.

The overlay deliberately sets no `env:`, `disable:` or version overrides, because those
are hashed. Key4hep packages therefore get the same hashes as the same packages built by
other groups on the same base, and are reused from the binary store instead of rebuilt.

## Prerequisites

- bits and its requirements (Python 3, git, Environment Modules), see the
  [bits installation instructions](https://github.com/bitsorg/bits#installation).
- A supported platform. The bits-console Key4hep community builds for x86_64 el8, el9
  and el10, aarch64-el9, and x86_64 Ubuntu 22.04, 24.04 and 26.04.

## Getting started

```bash
bits init key4hep.bits && cd key4hep.bits     # or: git clone https://github.com/bitsorg/key4hep.bits
bits use build --architecture x86_64-el9 --defaults key4hep::gcc15::opt --set release=LCG_110
bits build --dry-run key4hep
bits build key4hep                            # the complete stack
bits enter key4hep/latest
```

The `bits use` profile stores the settings in this checkout, so every later
`bits build` here gets them; options given on the command line still win. The build
architecture is `x86_64-el9-gcc15-opt`. A single package builds the same way, e.g.
`bits build DD4hep`. Check the machine with `bits doctor`. To build elsewhere,
`export BITS_WORK_DIR=/path/to/sw`. See
[Configuration](https://github.com/bitsorg/bits/blob/main/docs/USERGUIDE.md#4-configuration)
in the bits user guide.

## Notes for Key4hep users

- **Choosing defaults.** Name the group overlay (`key4hep`), then one compiler, one build
  type and optionally `cuda`, as described in
  [Composing profiles](https://github.com/bitsorg/stacks.bits#composing-profiles). Key4hep
  uses `gcc15::opt`, so builds run in `x86_64-el9-gcc15-opt`.
- **Always pass the release on the command line** (`--set release=LCG_110`, or record it
  with `bits use` as above). `main` is only the default. The value selects the
  `lcg.bits` and `stacks.bits` branches and the CVMFS `{release}` path segment, and it
  enters every package hash. A release chosen any other way hashes differently, so
  nothing built by the other groups is reused. The release must exist as a branch of
  both `lcg.bits` and `stacks.bits`.
- **The `key4hep` meta-package.** `key4hep.sh` builds nothing itself; it only requires
  the stack. A few versions are pinned inline (`acts = 44.4.0`,
  `k4actstracking = v00-02`). Everything else follows the `lcg.bits` branch selected by
  `release`. An inline pin changes only that package and its dependents.
- **CVMFS layout.** Builds publish under `/cvmfs/bits.cern.ch/key4hep` with the shared
  [stacks.bits layout](https://github.com/bitsorg/stacks.bits#cvmfs-layout); only the
  prefix differs. `prefix` must match `cvmfs_prefix` in the bits-console Key4hep community
  configuration, or an injected build refuses to publish. To preview a path without
  building, run
  `bits cvmfs-path -c . --defaults key4hep::gcc15::opt --set release=LCG_110 --admin --package <pkg> --version <v> --platform <arch>`.
- **Using the published modules.** Run
  `BITS_MODULEDIR=/cvmfs/bits.cern.ch/key4hep BITS_PLATFORM=x86_64-el9-gcc15-opt bitsenv enter <pkg>/<tag>`.
- **Publishing to the testbed.** Append the `testbed` overlay from
  [testbed.bits](https://github.com/bitsorg/testbed.bits) as the last profile, for example
  `--defaults key4hep::gcc15::opt::testbed`. It changes only the CVMFS repository and
  keeps the layout.
- **CI.** Nightly or on-commit builds are pipelines saved in bits-console
  (`communities/Key4hep/pipelines/<PIPELINE>.json`). A small `.gitlab-ci.yml` in a recipe
  repository can trigger one with `BITS_GROUP: Key4hep` and `BITS_PIPELINE: <name>`. The
  store, certification group and manifests repository are supplied by bits-console in CI,
  not set in this repository.

## Files

| File | Purpose |
|---|---|
| `defaults-key4hep.sh` | Key4hep overlay (`--defaults key4hep`): `stacks.bits` base, release tracking, CVMFS layout |
| `key4hep.sh` | Meta-package that requires the complete Key4hep stack |

## More information

- [Developing a package](https://github.com/bitsorg/bits/blob/main/docs/COOKBOOK.md#develop-and-iterate-on-a-single-package)
  with a local checkout (`bits init -c . <package>`);
  [sharing binaries through a store](https://github.com/bitsorg/bits/blob/main/docs/USERGUIDE.md#sharing-binaries-through-a-store)
- [stacks.bits](https://github.com/bitsorg/stacks.bits#readme) and
  [lcg.bits](https://github.com/bitsorg/lcg.bits#readme) READMEs: profiles, releases,
  CVMFS layout and the recipe pool; [bits-providers](https://github.com/bitsorg/bits-providers): the registry
- bits [User Guide](https://github.com/bitsorg/bits/blob/main/docs/USERGUIDE.md),
  [Cookbook](https://github.com/bitsorg/bits/blob/main/docs/COOKBOOK.md),
  [Reference](https://github.com/bitsorg/bits/blob/main/docs/REFERENCE.md)
- [bits-console](https://gitlab.cern.ch/buncic/bits-console): CI builds and CVMFS publishing

## License

This repository does not contain a LICENSE file yet.
