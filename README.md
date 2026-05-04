# qe-base

Prebuilt Docker base image for [Quantum ESPRESSO](https://www.quantum-espresso.org/) — serial CPU build, compiled from upstream sources on `debian:bookworm-slim`. Ships `pw.x` (plane-wave SCF, band structure, structural relaxation) and `dos.x` (density of states post-processing) at `/opt/qe/bin/`.

Designed as a thin, predictable base layer that downstream containers can `FROM` to add their own runtime environment, pseudopotentials, and entrypoint — without paying the ~3-minute compile cost on every build.

## When to use this image

**Good fits:**
- **CI fixtures** that need a real `pw.x` to test input generation, output parsing, or end-to-end workflow logic
- **Reproducibility artifacts** for published calculations — image tags are immutable, so `ghcr.io/material-codes/qe-base:7.4.1` ships exactly the QE binary that was current at release time
- **Education / classroom use** where students need a working QE without fighting a source build
- **Workflow runners** (e.g. material/core's `qerunner`) that want a known-good binary as a base layer
- **Small-to-medium calculations** that fit on a single node and don't need MPI

**Not a fit:**
- **Production HPC** — no MPI, no OpenMP, no GPU. For real HPC, use [NVIDIA NGC's QE container](https://catalog.ngc.nvidia.com/orgs/hpc/containers/quantum_espresso) (GPU-optimized) or your HPC center's hand-tuned build
- **Phonons / DFPT** — `ph.x` is not built; the build target list would need to be extended
- **CP / NEB / TDDFPT** — not built; same reason

## What's inside

| Path | Contents |
|---|---|
| `/opt/qe/bin/pw.x` | Plane-wave SCF, structural relaxation, band structure |
| `/opt/qe/bin/dos.x` | Density of states post-processing |

The image is `FROM debian:bookworm-slim` and **does not include runtime libraries** (BLAS, FFTW, libgfortran). Downstream consumers install what they need — see [Use as a base](#use-as-a-base) below. This keeps the base image small and lets consumers control their own dependency footprint.

**Build configuration:**

| Setting | Value |
|---|---|
| Compiler | `gfortran` (Debian bookworm) |
| BLAS | `libopenblas` (link-time only; not bundled) |
| FFTW | `libfftw3` (link-time only; not bundled) |
| MPI | disabled (`-DQE_ENABLE_MPI=OFF`) |
| OpenMP | disabled (`-DQE_ENABLE_OPENMP=OFF`) |
| Tests | disabled (`-DQE_ENABLE_TEST=OFF`) |
| Docs | disabled (`-DQE_ENABLE_DOC=OFF`) |

The build is two-stage: a `qe-builder` stage with the full compile toolchain (CMake, gfortran, dev headers), and a final `debian:bookworm-slim` stage that copies only `/opt/qe`. The final image carries no build artifacts beyond the binaries themselves.

## Pull

```sh
docker pull ghcr.io/material-codes/qe-base:7.4.1
```

| Tag pattern | Meaning |
|---|---|
| `<version>` (e.g. `7.4.1`) | Pinned to a specific QE release. Immutable. |
| `latest` | Tracks the most recent release tag. Moves over time. |

For reproducibility, **always pin a specific version** in production references; reserve `latest` for exploration.

## Use as a base

```dockerfile
FROM ghcr.io/material-codes/qe-base:7.4.1

# Add the runtime libraries QE links against. Versions match Debian bookworm.
RUN apt-get update && apt-get install -y --no-install-recommends \
        libopenblas0 \
        libfftw3-double3 \
        libfftw3-single3 \
        libgfortran5 \
 && rm -rf /var/lib/apt/lists/*

# Make pw.x and dos.x discoverable on PATH.
ENV PATH=/opt/qe/bin:$PATH
```

Pseudopotentials are not bundled (different downstream use cases need different families). For a curated PseudoDojo NC stringent v0.4 PBE/PBEsol set with a runtime-consumable manifest, see [github.com/material-codes/qe-pseudos](https://github.com/material-codes/qe-pseudos):

```dockerfile
COPY --from=ghcr.io/material-codes/qe-pseudos:pseudodojo-v0.4 /pseudo /opt/pseudo
```

## Build locally

```sh
docker build --build-arg QE_VERSION=7.4.1 -t qe-base:7.4.1 .
```

On Apple Silicon (M1/M2/M3), the build runs under qemu emulation when targeting `linux/amd64` — expect noticeably longer compile times (~10× slower) than on a native amd64 host. For local iteration on Apple Silicon, build natively:

```sh
docker build --platform linux/arm64 --build-arg QE_VERSION=7.4.1 -t qe-base:7.4.1-arm64 .
```

The published GHCR image is `linux/amd64` only.

## Bumping the QE version

1. Edit `ARG QE_VERSION` default in `Dockerfile` (both stages must match).
2. Commit, push to `main`. **No build runs yet** — the workflow only triggers on tags.
3. Cut the tag: `git tag v<new-version> && git push --tags`. The GHA workflow publishes `ghcr.io/material-codes/qe-base:<new-version>` and updates `latest`. ~3 minutes on a warm cache.

The trigger is `tags: ['v*']`, so unrelated tags like `docs-v1` would also fire the workflow — keep tag names limited to QE version pins.

## Versioning policy

Image tags follow QE's upstream release versioning (e.g. QE release `7.4.1` → image tag `7.4.1`). Patch releases get their own image tag and replace `latest`.

If a non-QE build dependency (Debian base, build-arg defaults) needs to change between QE releases, cut a suffixed tag like `v7.4.1-1` to keep the QE-version semantics unambiguous and preserve the immutability of the original `7.4.1` image.

## Licensing

The Dockerfile and CI in this repo are MIT-licensed (see `LICENSE`).

The published image **contains** Quantum ESPRESSO binaries built from upstream source and is therefore distributable under the QE license (GPL-2.0-or-later). When using the image in published work, please cite Quantum ESPRESSO per [the project's citation guidance](https://www.quantum-espresso.org/project/citing-q-e/).
