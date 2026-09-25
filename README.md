# key4hep.bits

Defaults and the stack meta-package for building **Key4hep** with [`bits`](../bits). This repository ships almost no package recipes of its own — the ~1100 recipes it builds against live in [`lcg.bits`](../lcg.bits). `key4hep.bits` is the *policy* layer for Key4hep: it declares the CVMFS publish layout for the `key4hep` area and the [`key4hep`](#the-key4hep-meta-package) meta-package that names the whole stack.

It is a thin overlay on [`stacks.bits`](../stacks.bits), the shared base every community builds on: the build environment, the compiler/build-type profiles, the `release` variable and the `lcg.bits` recipe pool all come from there. Key4hep adds nothing hashed, so its packages hash like the same packages built by any other group on the same base (a group that sets its own `env:` or `package_family`, as LHCb currently does, is not on the same base) and are **reused from the store** instead of rebuilt.

---

## Table of Contents
- [Repository Discovery & Provider Model](#repository-discovery--provider-model)
- [The `defaults-key4hep.sh` Overlay](#the-defaults-key4hepsh-overlay)
  - [The `system:` Block](#the-system-block)
- [Command-Line Usage](#command-line-usage)
  - [Composing Profiles](#composing-profiles)
  - [Previewing Publish Paths](#previewing-publish-paths)
- [Branches and Releases](#branches-and-releases)
- [The `key4hep` Meta-Package](#the-key4hep-meta-package)
- [Local Development](#local-development)
  - [Building Packages](#building-packages)
  - [Using the Module Environment](#using-the-module-environment)
  - [Building the Full Stack](#building-the-full-stack)
  - [Iteration Workflow](#iteration-workflow)
- [The S3 Content Store & Certification](#the-s3-content-store--certification)
  - [Store Inspection & Management](#store-inspection--management)
- [CI Pipelines](#ci-pipelines)
- [Files Overview](#files-overview)

---

## Repository Discovery & Provider Model

`bits` resolves recipes along an ordered search path (`BITS_PATH`). Beyond local `*.bits` checkouts, a repository can be pulled in on demand by a *repository-provider* package — an ordinary recipe carrying `provides_repository: true` whose `source` points at a recipe repo. `bits` clones it into `sw/REPOS/<pkg>/<hash>/`, adds it to `BITS_PATH` and rescans, repeating for nested providers until the graph is stable. Each provider's commit is folded into every package hash, so bumping a pool triggers a rebuild.

`key4hep.bits` requires **`stacks.bits`**, which requires **`lcg.bits`**:

```
key4hep.bits  ──requires──▶  stacks.bits  ──requires──▶  lcg.bits
  defaults-key4hep.sh          defaults-release.sh          ≈1100 recipes: ROOT, Geant4,
  key4hep.sh                   gcc13/14/15, clang, dbg,      podio, DD4hep, Gaudi, k4*, …
                               cuda, dev3/dev4
```

- `stacks.bits` supplies `defaults-release` (the base every chain starts from: the shared `env:`, `package_family`, sandbox/source policy, `release: main`) and the axis profiles.
- `lcg.bits` supplies every recipe. The branch that is cloned is selected by `release` (see [Branches and Releases](#branches-and-releases)).
- `key4hep.bits` adds only what is Key4hep's: the CVMFS namespace and the meta-package.

---

## The `defaults-key4hep.sh` Overlay

Composed with `--defaults key4hep[::gcc15]`. Besides `system:` it carries only the base and the release tracking, identical in every stacks-based overlay:

```yaml
variables:
  release: "main"          # default only — pass --set release=LCG_110
requires:
  - stacks.bits
overrides:
  lcg.bits:
    tag: "%(release)s"     # recipe pool at the release branch
  stacks.bits:
    tag: "%(release)s"     # policy layer at the release branch
```

`release` is declared here (not only in `stacks.bits`) because the overrides are expanded on the first discovery pass, before `stacks.bits` is loaded.

It deliberately has **no `env:`, no `disable:` and no version overrides.** Those are hashed inputs: any of them would give every Key4hep package a hash different from the same package in the other stacks and turn store reuse into a full rebuild. Key4hep-specific version choices live as inline pins in `key4hep.sh` (see [The `key4hep` Meta-Package](#the-key4hep-meta-package)).

### The `system:` Block

`system:` holds *where* things publish. It is never folded into package hashes, so the same binary can be published to any group's tree without changing identity.

| `system:` field | Value |
|---|---|
| `prefix` | `/cvmfs/bits.cern.ch/key4hep/releases` — the CVMFS root |
| `cvmfs_user_prefix` | `/cvmfs/bits.cern.ch/key4hep/user` — per-user publishes go to `<user_prefix>/<login>`, a **sibling** of `releases` |
| `cvmfs_releases_template` | `{prefix}/{release}/{pkg}/{tag}/{platform}` |
| `cvmfs_modules_template` | `{prefix}/{release}/{platform}/Modules/modulefiles/{pkg}` |
| `cvmfs_shared_path_template` | `{prefix}/{release}/noarch/{pkg}/{tag}` |

A package built for `LCG_110` therefore lands at `…/key4hep/releases/LCG_110/<pkg>/<tag>/<platform>`. On the `main` line the `{release}/` segment collapses away, so the path is `…/key4hep/releases/<pkg>/<tag>/<platform>`, as before.

> `prefix` is an **auth boundary**: bits-console injects the authoritative value from `communities/Key4hep/ui-config.yaml` (`cvmfs_prefix`), and the injected value wins. The value here must match it (kept in sync by a bits-admin PR) or an injected build refuses to publish.

> To publish a Key4hep build into the testbed instead, append the testbed overlay last: `--defaults key4hep::gcc15::testbed` (with [`testbed.bits`](../testbed.bits) on `BITS_PATH`; the bits-console Testbed community loads it). It replaces only the root (`/cvmfs/test.cvmfs.io`) and the user prefix; the layout above is kept.

> `remote_store` / `certify_group` / `manifests_remote` are not set here — locally you pass the store on the command line (or `~/.bits/s3keys`), and in CI bits-console supplies them as job variables.

---

## Command-Line Usage

Profiles are composed with `::`. `release` (from `stacks.bits`) is always the implicit base, so you name the group overlay and the axes:

```bash
bits build DD4hep  --defaults key4hep::gcc15                        # main line
bits build DD4hep  --defaults key4hep::gcc15::dbg                   # + Debug
bits build key4hep --defaults key4hep::gcc15 --set release=LCG_110  # whole stack on LCG_110
```

### Composing Profiles

Each axis contributes an `append_arch` suffix, so the arch string is the `bits` `BINARY_TAG`:

| Axis | Profiles | Sets | `append_arch` | Lives in |
|---|---|---|---|---|
| Compiler | `gcc13`, `gcc14`, `gcc15`, `clang` | `GCC-Toolchain` tag (or `prefer_system` for clang) + the C++ standard | `-gcc13` … `-clang` | `stacks.bits` |
| Build type | *(base)*, `dbg` | `CMAKE_BUILD_TYPE` = `RELWITHDEBINFO` / `Debug` | `-dbg` | `stacks.bits` |
| Feature | `cuda` | CUDA knobs | `-cuda` | `stacks.bits` |
| Release line | `dev3`, `dev4` | `release` + that line's version overrides | *(none)* | `stacks.bits` |
| Group | `key4hep` | CVMFS namespace | *(none)* | **this repo** |
| Publish target | `testbed` | CVMFS root only | *(none)* | `testbed.bits` |

The C++ standard is owned by the compiler axis (gcc13/14 → c++20, gcc15 → c++23, clang → c++20).

### Previewing Publish Paths

`bits cvmfs-path -c . --defaults key4hep::gcc15 --admin --package <pkg> --version <v> --platform <p>` prints the exact publish path a build would use (without `--admin`, a user path; pass `--login`).

---

## Branches and Releases

The single `release` variable names **both** the `lcg.bits` branch to build against and the `{release}` segment of the CVMFS path, so a release's recipes and its install tree always match. `bits` resolves it, highest precedence first:

**Pass the release on the command line** (`--set release=LCG_110`); `main` is only the default. Every stacks-based group (atlas, lhcb, key4hep, ship) follows this rule, because a `--set` value is also exported into the build environment and enters every package hash: a release chosen any other way (a `release:` in a profile, or the checkout's branch name) hashes differently, and nothing the other groups built would be reused. Reuse also needs the same `lcg.bits` and `stacks.bits` commits and the same compiler/build-type profiles.

(For reference, `bits` resolves it as: an explicit non-trunk value → the working-directory branch name, `-patches` stripped → `main`, where `main` drops the `{release}` path segment.) The effective release must exist as an `lcg.bits` and a `stacks.bits` branch.

---

## The `key4hep` Meta-Package

`key4hep.sh` is a meta-package: it builds nothing itself and simply `requires` the full stack, so one command builds everything and the dependency graph does the ordering.

It names the Key4hep core (`podio`, `EDM4hep`, `DD4hep`, `Gaudi`, `acts`, the `k4*` framework and reconstruction packages), the iLCSoft/Marlin family (`marlin*`, `LCIO`, `lcfiplus`, …), the FCC packages (`fcc*`), and the shared externals they need. Version pins live inline where a specific version is required, e.g.:

```yaml
requires:
  - acts = 44.4.0
  - k4actstracking = v00-02
```

Everything else floats with the recipe pool, so the `lcg.bits` branch selected by `release` decides the versions. An inline pin changes only that package and what depends on it; everything else stays reusable.

---

## Local Development

Building is done with `bits`; exploring and using the resulting module environment is done with **`bitsenv`**, the [Environment Modules] front-end. A build installs to `sw/<arch>/<pkg>/<ver>-<rev>/` and generates a modulefile named `<package>/<version>` that `bitsenv` can then load.

### Building Packages

**Build** a single package (work dir defaults to `sw`, arch auto-detected):

```bash
bits build DD4hep --defaults key4hep::gcc15
bits build DD4hep --defaults key4hep::gcc15 -a ubuntu2510_x86-64-gcc15 -w /scratch/sw
bits deps  key4hep --defaults key4hep::gcc15      # inspect the dependency tree first
```

### Using the Module Environment

**Discover** the built modules:

```bash
bitsenv q                    # list every available module (alias: bitsenv query)
bitsenv q k4                 # ...matching a regexp
```

**Test / use** a package in its module environment — three ways (`bitsenv [-p <platform>] [-m <modules dir>] <verb>`):

```bash
# a) interactive subshell with the module(s) loaded; `exit` to leave.
bitsenv enter DD4hep/v01-33
bitsenv enter DD4hep/v01-33,ROOT/v6.38.00      # several modules, comma-separated

# b) run ONE command in the environment (exit code preserved):
bitsenv setenv DD4hep/v01-33 -c ddsim --help   # everything after -c runs as-is

# c) inject the environment into your CURRENT shell (note the backticks):
eval `bitsenv printenv DD4hep/v01-33`
bitsenv checkenv DD4hep/v01-33                 # sanity-check the module env
```

### Building the Full Stack

**Build the full stack** via the meta-package in this repo — it pulls in the whole set as dependencies:

```bash
bits build key4hep --defaults key4hep::gcc15   # the complete Key4hep stack
```

### Iteration Workflow

**Iterate**: edit a recipe in `lcg.bits` on a branch, re-run `bits build` (only what changed rebuilds — see [The S3 Content Store](#the-s3-content-store--certification) on reuse), and `bits clean` to reset the build area. Because the local install tree already carries the arch layout, what you test locally is exactly what gets published.

---

## The S3 Content Store & Certification

Three artefacts, deliberately separate:

- **S3 content store** — a *content-addressed* cache of build tarballs (`TARS/<arch>/store/<hash>/…`, hash-only). Identical inputs → identical hash → identical binary, so any builder can **reuse** a prebuilt package instead of rebuilding. This is why the store exists: it makes builds fast and reproducible across machines and CI, and it's the substrate certification trusts. Configured via `system.remote_store` (`b3://<bucket>::rw`); credentials in `~/.bits/s3keys` (or `$BITS_AWS_KEYS_FILE`), store override `$BITS_S3_STORE`.
- **CVMFS release tree** — the *path-addressed* deployment users actually mount (`…/key4hep/releases/[<release>/]<pkg>/<tag>/<platform>`).
- **Signed common manifest** — the *trust unit*: what a client verifies before reusing a binary.

Reuse happens automatically at build time: for each dependency `bits` resolves a hash and, if that object is already in the store (`from_remote_store`, with `--check-store`), downloads it rather than building. A finished build uploads its tarball for the next consumer. (`bits build --reuse-policy relaxed --reuse-base <build_id>` can graft a deployed release's binaries.)

```bash
bits build <pkg> …            # checks the store, builds only what's missing, uploads results
bits publish <pkg> …          # relocates the install to its CVMFS path and streams it
                              #   to the ingestion spool → the release tree
bits certify …                # merges published build manifests into ONE common manifest,
                              #   validates every content hash against the S3 store, and
                              #   signs it with the release Ed25519 key (clients trust this)
```

`certify` is what turns a pile of uploaded tarballs into something safe to reuse: it checks each hash really is in the store and signs the result. `certify_group`, `manifests_remote` (and the release key) configure it — supplied by bits-console in CI.

### Store Inspection & Management

**Inspect / verify / clean the store** with `bits store`:

```bash
bits store ls   --arch A --group G --package P --version V   # list (manifest-aware selection)
bits store verify [--arch A] [--deep] [--orphans]            # integrity check vs manifests
bits store rm   <selection> [-n]                             # delete (e.g. --orphans, --expired); -n dry-run
bits gc                                                      # reachability GC: roots = hashes in the
                                                             #   verified signed manifest; fail-closed
```

Normally you don't run publish/certify by hand — the bits-console cvmfs-prepub pipeline does it (see [CI Pipelines](#ci-pipelines)). Locally you mostly `build` + `enter`/`setenv` to test, and use `bits store` to inspect what reuse will pull.

---

## CI Pipelines

A commit to `lcg.bits` **or** `key4hep.bits` (including a GitLab pull-mirror sync) can fire a **designated pipeline** configured and saved in **bits-console**, giving nightly/CI-style rebuilds without redefining the build here.

- The build definition (packages, platforms, defaults chain, providers, publish/certify) is authored in the console's **Build modal → "Save as pipeline"** and stored at `communities/Key4hep/pipelines/<PIPELINE>.json`.
- A small `.gitlab-ci.yml` in the recipe repo only *fires* it, multi-project-triggering bits-console with `BITS_GROUP: Key4hep` and `BITS_PIPELINE: on-commit`; the downstream `run-group-pipeline` job fans out one cvmfs-prepub build (build → publish → certify) per enabled entry.

One-time setup (GitLab UI):

1. bits-console → Settings → CI/CD → **Token Access** → add the recipe project to the `CI_JOB_TOKEN` allowlist.
2. If the recipe repo is a pull-mirror, enable **Mirroring → "Trigger pipelines for mirror updates"** (the `.gitlab-ci.yml` must be on the mirrored branch).
3. In the console, build the stack in the Build modal, tick the options, and **Save as pipeline**, naming it to match `BITS_PIPELINE`.

The same saved pipeline can also run on a schedule (nightly) or on demand from the console — the commit trigger is just one entry point.

---

## Files Overview

| File | Role |
|---|---|
| `defaults-key4hep.sh` | Key4hep group overlay (`--defaults key4hep`): `stacks.bits` base, release tracking, CVMFS namespace |
| `key4hep.sh` | meta-package pulling in the complete Key4hep stack |

The base profile (`defaults-release`) and the compiler/build-type/feature profiles (`gcc13/14/15`, `clang`, `dbg`, `cuda`, `dev3/dev4`) come from [`stacks.bits`](../stacks.bits), which `bits` pulls in automatically.

[Environment Modules]: https://modules.readthedocs.io/
