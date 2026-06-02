# syntax=docker/dockerfile:1.7

# Builder: compile Quantum ESPRESSO from source on Debian bookworm.
FROM debian:bookworm AS qe-builder
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        gfortran \
        cmake \
        libopenblas-dev \
        libfftw3-dev \
        git \
        wget \
        ca-certificates \
 && rm -rf /var/lib/apt/lists/*

ARG QE_VERSION=7.5
WORKDIR /src
RUN wget -q -O qe.tar.gz \
        "https://gitlab.com/QEF/q-e/-/archive/qe-${QE_VERSION}/q-e-qe-${QE_VERSION}.tar.gz" \
 && tar -xzf qe.tar.gz \
 && cd q-e-qe-${QE_VERSION} \
 && cmake -B build -S . \
        -DCMAKE_Fortran_COMPILER=gfortran \
        -DQE_ENABLE_MPI=OFF \
        -DQE_ENABLE_OPENMP=OFF \
        -DQE_ENABLE_TEST=OFF \
        -DQE_ENABLE_DOC=OFF \
 && cmake --build build --target pw pp -j"$(nproc)" \
 && mkdir -p /opt/qe/bin \
 && cp build/bin/pw.x build/bin/dos.x /opt/qe/bin/ \
 && cd .. && rm -rf qe.tar.gz q-e-qe-${QE_VERSION}

# Final stage: ship only /opt/qe on top of debian:bookworm-slim. Downstream
# images FROM this and add their own runtime libs + entrypoint.
FROM debian:bookworm-slim
ARG QE_VERSION=7.5
COPY --from=qe-builder /opt/qe /opt/qe
LABEL org.opencontainers.image.title="qe-base" \
      org.opencontainers.image.version="${QE_VERSION}" \
      org.opencontainers.image.source="https://github.com/material-codes/qe-base" \
      org.opencontainers.image.description="Prebuilt Quantum ESPRESSO ${QE_VERSION} (pw.x, dos.x) — serial CPU build."
