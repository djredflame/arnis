# syntax=docker/dockerfile:1

# Build the full project, with optional validation for slower CI-style runs.
FROM rust:1.88-slim-bookworm AS build

ENV CARGO_NET_GIT_FETCH_WITH_CLI=true
ENV DEBIAN_FRONTEND=noninteractive
ARG ARNIS_RUN_BUILD_VALIDATION=0

# Linux/Debian build dependencies:
# - Tauri/WebKit base: build-essential, curl, file, wget,
#   libwebkit2gtk-4.1-dev, libayatana-appindicator3-dev, librsvg2-dev
# - Project/build extras: git, libgtk-3-dev, libsoup-3.0-dev, libxdo-dev,
#   libssl-dev, pkg-config, ca-certificates, fonts-dejavu-core
RUN apt-get update && apt-get install -y --no-install-recommends \
  build-essential \
  ca-certificates \
  curl \
  file \
  fonts-dejavu-core \
  git \
  libayatana-appindicator3-dev \
  libgtk-3-dev \
  librsvg2-dev \
  libsoup-3.0-dev \
  libssl-dev \
  libwebkit2gtk-4.1-dev \
  libxdo-dev \
  pkg-config \
  wget \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /src

COPY . /src/

# Build GUI-enabled artifacts before producing runtime images.
RUN cargo build --locked --all-targets --all-features --release
RUN cp /src/target/release/arnis /tmp/arnis-gui
RUN if [ "${ARNIS_RUN_BUILD_VALIDATION}" = "1" ]; then \
    attempts=0; \
    until cargo test --locked --all-targets --all-features; do \
      attempts=$((attempts + 1)); \
      if [ "$attempts" -ge 5 ]; then \
        exit 1; \
      fi; \
      echo "Retrying live test suite after transient network failure (${attempts}/5)..."; \
      sleep 5; \
    done; \
  else \
    echo "Skipping build-time cargo test validation (ARNIS_RUN_BUILD_VALIDATION=${ARNIS_RUN_BUILD_VALIDATION})."; \
  fi

# Build the CLI-only release binary used by headless/container workflows.
RUN cargo build --locked --release --no-default-features
RUN cp /src/target/release/arnis /tmp/arnis-cli

# Reuse the build environment for manual reruns of the live test suite.
FROM build AS test-runtime

# Linux-only desktop/Tauri runtime image.
FROM debian:bookworm-slim AS gui-runtime

ENV DEBIAN_FRONTEND=noninteractive

# Runtime libraries required by the Linux/Tauri binary.
RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  fonts-dejavu-core \
  libayatana-appindicator3-1 \
  libgtk-3-0 \
  librsvg2-2 \
  libsoup-3.0-0 \
  libwebkit2gtk-4.1-0 \
  libxdo3 \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /data

COPY --from=build /tmp/arnis-gui /usr/local/bin/arnis

# Linux-only headless GUI runtime with Xvfb + x11vnc for Docker-only access.
FROM gui-runtime AS gui-headless-runtime

RUN apt-get update && apt-get install -y --no-install-recommends \
  fluxbox \
  x11-utils \
  x11vnc \
  xvfb \
  && rm -rf /var/lib/apt/lists/*

COPY scripts/docker/headless-gui-entrypoint.sh /usr/local/bin/headless-gui-entrypoint
RUN chmod +x /usr/local/bin/headless-gui-entrypoint

# Minimal CLI runtime image for generation jobs.
FROM python:3.13-slim-bookworm AS cli-runtime

ENV ARNIS_BINARY=/usr/local/bin/arnis

WORKDIR /data

RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  && rm -rf /var/lib/apt/lists/*

COPY --from=build /tmp/arnis-cli /usr/local/bin/arnis
