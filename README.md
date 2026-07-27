# key4hep.bits

Defaults and the stack meta-package for building **Key4hep** with [`bits`](../bits). This repository ships almost no package recipes of its own — the ~1100 recipes it builds against live in [`lcg.bits`](../lcg.bits). `key4hep.bits` is the *policy* layer for Key4hep: it declares the CVMFS publish layout for the `key4hep` area, the build environment, and the [`key4hep`](#the-key4hep-meta-package) meta-package that names the whole stack.

It is a sibling of [`stacks.bits`](../stacks.bits) (the LCG stack policy) rather than a layer on top of it: both point at the same `lcg.bits` recipe pool, but publish to different CVMFS roots.

---

## Table of Contents
- [Repository Discovery & Provider Model](#repository-discovery--provider-model)
  - [What this repository loads](#what-this-repository-loads)
  - [Loading `stacks.bits` instead](#loading-stacksbits-instead)
- [The `defaults-release.sh` Profile](#the-defaults-releasesh-profile)
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

`bits` resolves recipes along an ordered search path (`BITS_PATH`), seeded from `bits.rc` (`search_path`) or the environment. Preferably, beyond local `*.bits` checkouts and with zero configuration, a repository can be pulled in on demand by a *repository-provider* package — an ordinary recipe carrying `provides_repository: true` whose `source` points at a recipe repo. When `bits` meets one while scanning dependencies it clones the source into `sw/REPOS/<pkg>/<hash>/`, adds it to `BITS_PATH`, and rescans — repeating for **nested** providers until the graph is stable. Each provider's commit hash is folded into every package's build hash, so bumping a pool triggers a rebuild.

**`lcg.bits` is itself a versioned package.** Its provider recipe is just:

```yaml
package: lcg.bits
version: "1"
tag: "main"                 # which branch/commit of the recipe pool to clone
provides_repository: true
always_load: true
source: https://github.com/bitsorg/lcg.bits
```

### What this repository loads

`key4hep.bits/defaults-release.sh` declares a single provider:

```yaml
requires:
  - lcg.bits

overrides:
  lcg.bits:
    tag: "%(release)s"      # the release label selects the recipe-pool branch
```

so the chain resolved for a Key4hep build is:

```
key4hep.bits  ──requires──▶  lcg.bits          (≈1100 recipes: ROOT, Geant4, podio, DD4hep, k4*, …)
   │
   └── defaults-release.sh, defaults-key4hep.sh, key4hep.sh   (this repo)
```

Only one hop: `key4hep.bits` supplies the policy, `lcg.bits` supplies every recipe it builds. Nothing else is cloned, and `%(release)s` pins *which branch* of the pool is used (see [Branches and Releases](#branches-and-releases)).

### Loading `stacks.bits` instead

Because provider resolution is recursive, a group repository can equally require **`stacks.bits`**, which itself requires `lcg.bits` — giving a two-hop chain:

```
key4hep.bits  ──requires──▶  stacks.bits  ──requires──▶  lcg.bits
```

`bits` clones `stacks.bits`, rescans, finds its `requires: lcg.bits`, clones that too, and keeps going until the graph stops changing. The practical difference is what lands on `BITS_PATH`: with `stacks.bits` in the chain you also inherit its **compiler and build-type profiles** — `defaults-gcc13/14/15`, `defaults-clang`, `defaults-dbg`, `defaults-cuda`, `defaults-dev3/dev4` — and its meta-packages (`externals`, `generators`).

To switch, replace the `requires` block with a version-pinned provider:

```yaml
requires:
  - stacks.bits

overrides:
  stacks.bits:
    tag: "v1.2.0"           # or a branch: pin the exact policy layer you want
```

Note that pinning `stacks.bits` pins the *policy* layer; the recipe pool underneath is then selected by `stacks.bits`'s own `overrides: lcg.bits: tag: "%(release)s"`. Two profiles named `defaults-release` would exist in that configuration — the one nearest the front of `BITS_PATH` wins, so a group that wants its own CVMFS layout keeps its local `defaults-release.sh` and inherits only the axis profiles from `stacks.bits`.

**Today `key4hep.bits` takes the one-hop route** and requires `lcg.bits` directly. Its `defaults-release.sh` therefore carries the full Key4hep policy itself, and the compiler-axis profiles referenced below are available only when `stacks.bits` is also on `BITS_PATH` (a local checkout, `search_path`, or the provider above).

---

## The `defaults-release.sh` Profile

`defaults-release` is the base profile every build inherits. Its top-level keys:

| Key | Purpose | Hashed? |
|---|---|---|
| `package` / `version` | identifies the pseudo-package | — |
| `requires` | what the base pulls in (here: `lcg.bits`, the recipe pool) | yes |
| `env:` | build environment exported to **every** package (`CFLAGS`, `CMAKE_BUILD_TYPE`, `MACOSX_DEPLOYMENT_TARGET`, `ENABLE_IPO`) | **yes** — folded into every package hash, so a flag change yields a distinct, reproducible identity |
| `variables:` | `%(name)s` template values used in overrides/recipes — notably `release` | indirectly (only through what they expand) |
| `overrides:` | per-package field overrides (`source`/`tag`/`version`), e.g. `lcg.bits: tag: "%(release)s"` | yes (changes the resolved recipe) |
| `system:` | deployment/policy — see below | **no** — never folded into package hashes |

Deliberately **not** set here: `CXXFLAGS` / `-std`. The C++ standard is owned by the compiler axis (`stacks.bits/defaults-gccNN`, `defaults-clang`), so `dbg`/`cuda` and this base compose with any compiler without clobbering `-std`.

### The `system:` Block

The **`system:` block** holds everything about *where and how* things build and publish, deliberately kept out of the package hash (the same binary can be published to different paths without changing identity):

| `system:` field | Meaning |
|---|---|
| `sandbox_network` | build-sandbox network policy (`on`/`off`); recipes may still override per package |
| `build_oversubscribe` | parallelism factor (`1.25` → `-j` slightly above core count) |
| `prefix` | the CVMFS releases root, `/cvmfs/sft-nightlies-test.cern.ch/key4hep/releases` |
| `cvmfs_user_prefix` | root for per-user (non-admin) publishes: `<user_prefix>/<login>` — a **sibling** of `releases`, not `{prefix}/user` |
| `cvmfs_releases_template` | per-package publish path |
| `cvmfs_modules_template` | modulefile publish path |
| `cvmfs_shared_path_template` | noarch/shared publish path |

The current templates:

```
prefix:   /cvmfs/sft-nightlies-test.cern.ch/key4hep/releases
user:     /cvmfs/sft-nightlies-test.cern.ch/key4hep/user
releases: {prefix}/{pkg}/{tag}/{platform}
shared:   {prefix}/noarch/{pkg}/{tag}
modules:  {prefix}/{platform}/Modules/modulefiles/{pkg}
```

A package therefore lands at `…/key4hep/releases/<pkg>/<tag>/<platform>` — flatter than the LCG layout, which inserts `{release}` and `{family}` segments.

> `prefix` is an **auth boundary**: bits-console injects the authoritative value from `communities/Key4hep/ui-config.yaml` (`cvmfs_prefix`), and the injected value WINS. The value in this file must match it (kept in sync by a bits-admin PR) or an injected build refuses to publish; it exists so that local `bits build` (no injection) works and so the declaration is checkable.

> `key4hep.bits` does not set `remote_store` / `certify_group` / `manifests_remote` itself — locally you pass the store on the command line (or `~/.bits/s3keys`), and in CI bits-console supplies them as job variables.

---

## Command-Line Usage

Options are **composable profiles** combined with `::`. `release` is always the implicit base (auto-prepended), so you only name the overlays:

```bash
bits build DD4hep --defaults gcc15            # release + gcc15   (c++23, RelWithDebInfo)
bits build DD4hep --defaults gcc15::dbg       # + Debug build type
bits build key4hep --defaults gcc15           # the whole stack meta-package
```

The overlay profiles (`gcc15`, `dbg`, `cuda`, …) come from `stacks.bits` — see [Loading `stacks.bits` instead](#loading-stacksbits-instead). With only `lcg.bits` loaded, `--defaults key4hep` (this repo's own overlay) and the base profile are what is available.

### Composing Profiles

The profiles fall on independent **axes**, each contributing an `append_arch` suffix (so the arch string is the `bits` `BINARY_TAG`):

| Axis | Profiles | Sets | `append_arch` | Lives in |
|---|---|---|---|---|
| Compiler | `gcc13`, `gcc14`, `gcc15`, `clang` | `GCC-Toolchain` tag (or `prefer_system` for clang) + the C++ standard in `CXXFLAGS` | `-gcc13` … `-clang` | `stacks.bits` |
| Build type | *(base)*, `dbg` | `CMAKE_BUILD_TYPE` = `RELWITHDEBINFO` / `Debug` | `-dbg` | `stacks.bits` |
| Feature | `cuda` | CUDA knobs (never `CXXFLAGS`) | `-cuda` | `stacks.bits` |
| Group | `key4hep` | Key4hep-specific env/overrides | *(none)* | **this repo** |

The C++ standard is owned by the **compiler axis** (gcc13/14 → c++20, gcc15 → c++23, clang → c++20), never by the base or the build-type/feature profiles.

### Previewing Publish Paths

`bits cvmfs-path -c . --defaults <chain> --package <pkg> --version <v> --platform <p>` prints the exact publish path a build would use — handy to preview where a chain lands before building.

---

## Branches and Releases

The `release` label names **two things at once**: the **`lcg.bits` branch** to build against (`overrides: lcg.bits: tag: "%(release)s"`) and the tag `key4hep.bits` converges to. Unlike the LCG layout, it is *not* a path segment here — the Key4hep templates have no `{release}` slot. `bits` resolves it, highest precedence first:

1. an explicit, non-trunk `release:` in the chosen defaults (`dev3`, `dev4`, a tagged `LCG_107`),
2. else the **working-directory branch name** (`-patches` stripped, so `LCG_107-patches` → `LCG_107`),
3. else **`main`** — the default: build against `lcg.bits` `main`.

The effective release **must exist as an `lcg.bits` branch** — that branch *is* the recipe pool. Check out `feature-x` in your working copy and the build tracks `lcg.bits` `feature-x`, isolated from `main`.

---

## The `key4hep` Meta-Package

`key4hep.sh` is a meta-package: it builds nothing itself and simply `requires` the full stack, so one command builds everything and the dependency graph does the ordering.

It names the Key4hep core (`podio`, `EDM4hep`, `DD4hep`, `Gaudi`, `acts`, the `k4*` framework and reconstruction packages), the iLCSoft/Marlin family (`marlin*`, `LCIO`, `lcfiplus`, …), the FCC packages (`fcc*`), and the shared externals they need. Version pins live inline where a specific version is required, e.g.:

```yaml
requires:
  - acts = 44.4.0
  - k4actstracking = v00-02
```

Everything else floats with the recipe pool, so the `lcg.bits` branch selected by the release label decides the versions.

---

## Local Development

Building is done with `bits`; exploring and using the resulting module environment is done with **`bitsenv`**, the [Environment Modules] front-end. A build installs to `sw/<arch>/<pkg>/<ver>-<rev>/` and generates a modulefile named `<package>/<version>` that `bitsenv` can then load.

### Building Packages

**Build** a single package (work dir defaults to `sw`, arch auto-detected):

```bash
bits build DD4hep --defaults gcc15
bits build DD4hep --defaults gcc15 -a ubuntu2510_x86-64-gcc15 -w /scratch/sw
bits deps  key4hep --defaults gcc15      # inspect the dependency tree first
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
bits build key4hep --defaults gcc15           # the complete Key4hep stack
```

### Iteration Workflow

**Iterate**: edit a recipe in `lcg.bits` on a branch, re-run `bits build` (only what changed rebuilds — see [The S3 Content Store](#the-s3-content-store--certification) on reuse), and `bits clean` to reset the build area. Because the local install tree already carries the arch layout, what you test locally is exactly what gets published.

---

## The S3 Content Store & Certification

Three artefacts, deliberately separate:

- **S3 content store** — a *content-addressed* cache of build tarballs (`TARS/<arch>/store/<hash>/…`, hash-only). Identical inputs → identical hash → identical binary, so any builder can **reuse** a prebuilt package instead of rebuilding. This is why the store exists: it makes builds fast and reproducible across machines and CI, and it's the substrate certification trusts. Configured via `system.remote_store` (`b3://<bucket>::rw`); credentials in `~/.bits/s3keys` (or `$BITS_AWS_KEYS_FILE`), store override `$BITS_S3_STORE`.
- **CVMFS release tree** — the *path-addressed* deployment users actually mount (`…/key4hep/releases/<pkg>/<tag>/<platform>`).
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
| `defaults-release.sh` | base: `system:` (CVMFS paths/policy), `env:`, `release` label, requires `lcg.bits` |
| `defaults-key4hep.sh` | Key4hep group overlay (`--defaults key4hep`) — env/overrides specific to the stack |
| `key4hep.sh` | meta-package pulling in the complete Key4hep stack |

Compiler/build-type/feature profiles (`gcc13/14/15`, `clang`, `dbg`, `cuda`, `dev3/dev4`) are **not** in this repository — they live in [`stacks.bits`](../stacks.bits) and are available when it is on `BITS_PATH`.

[Environment Modules]: https://modules.readthedocs.io/
