# syntax=docker/dockerfile:1.4

# ============================================================================
# STAGE: base - Common system dependencies
# ============================================================================
FROM node:20-bookworm-slim AS base

LABEL maintainer="zkolar"
LABEL description="Zero-Knowledge Grade Verification System"

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ============================================================================
# STAGE: circom-builder - Build Circom from source
# ============================================================================
FROM rust:1.75-slim-bookworm AS circom-builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    && rm -rf /var/lib/apt/lists/*

# Build Circom from source for reproducibility
RUN git clone --depth 1 --branch v2.1.8 https://github.com/iden3/circom.git /circom \
    && cd /circom \
    && cargo build --release \
    && mv /circom/target/release/circom /usr/local/bin/circom

# ============================================================================
# STAGE: foundry-builder - Get Foundry binaries
# ============================================================================
FROM ghcr.io/foundry-rs/foundry:latest AS foundry-builder

# ============================================================================
# STAGE: node-deps - Cached npm dependencies
# ============================================================================
FROM base AS node-deps

WORKDIR /deps

# Copy only package files for caching
COPY package*.json ./

# Install all dependencies (snarkjs needs its peer deps)
RUN npm install && \
    npm install -g snarkjs@0.7.4 && \
    # Create a proper global snarkjs wrapper that uses local node_modules
    mkdir -p /deps/snarkjs-global && \
    cd /deps/snarkjs-global && \
    npm init -y && \
    npm install snarkjs@0.7.4

# ============================================================================
# STAGE: development - Full development environment
# ============================================================================
FROM base AS development

# Install build-essential for native modules
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    python3 \
    dos2unix \
    && rm -rf /var/lib/apt/lists/*

# Copy Circom from builder
COPY --from=circom-builder /usr/local/bin/circom /usr/local/bin/circom

# Copy Foundry tools
COPY --from=foundry-builder /usr/local/bin/forge /usr/local/bin/forge
COPY --from=foundry-builder /usr/local/bin/cast /usr/local/bin/cast
COPY --from=foundry-builder /usr/local/bin/anvil /usr/local/bin/anvil
COPY --from=foundry-builder /usr/local/bin/chisel /usr/local/bin/chisel

# Copy node modules from node-deps stage
COPY --from=node-deps /deps/node_modules /app/node_modules

# Create snarkjs wrapper that uses local node_modules
RUN echo '#!/bin/bash\nexec node /app/node_modules/.bin/snarkjs "$@"' > /usr/local/bin/snarkjs && \
    chmod +x /usr/local/bin/snarkjs

WORKDIR /app

# Copy project files
COPY --chown=node:node . .

# Fix line endings for scripts (Windows compatibility)
RUN find bin -type f -name "*.sh" -exec dos2unix {} \; 2>/dev/null || true \
    && chmod +x bin/*.sh

# Create directories with correct permissions
RUN mkdir -p circuits/build node_modules out cache lib \
    && chown -R node:node circuits/build node_modules out cache lib

# Environment
ENV PATH=/usr/local/bin:$PATH
ENV FOUNDRY_DISABLE_NIGHTLY_WARNING=1
ENV NODE_ENV=development

USER node

# Default: interactive shell
CMD ["/bin/bash"]

# ============================================================================
# STAGE: ci - Minimal image for CI/CD testing
# ============================================================================
FROM base AS ci

# Copy Foundry tools only
COPY --from=foundry-builder /usr/local/bin/forge /usr/local/bin/forge
COPY --from=foundry-builder /usr/local/bin/cast /usr/local/bin/cast

# Copy node modules
COPY --from=node-deps /deps/node_modules /app/node_modules

WORKDIR /app

# Copy project files
COPY --chown=node:node . .

# Create output directories
RUN mkdir -p out cache lib \
    && chown -R node:node out cache lib

# Environment
ENV PATH=/usr/local/bin:$PATH
ENV FOUNDRY_PROFILE=ci
ENV FOUNDRY_DISABLE_NIGHTLY_WARNING=1

USER node

# CI runs tests by default
CMD ["forge", "test", "-vvv"]

# ============================================================================
# STAGE: production - Slim runtime for proof generation only
# ============================================================================
FROM node:20-bookworm-slim AS production

# Minimal deps for snarkjs
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy node_modules with snarkjs and all dependencies
COPY --from=node-deps /deps/node_modules ./node_modules

# Copy only what's needed for proof generation
COPY --chown=node:node bin/generate_test_proofs.sh ./bin/

# Create directories for inputs/outputs
RUN mkdir -p circuits/build circuits/test_inputs circuits/test_proofs \
    && chown -R node:node circuits/ bin/

RUN chmod +x bin/*.sh

# Create snarkjs wrapper that uses local node_modules
RUN echo '#!/bin/bash\nexec node /app/node_modules/.bin/snarkjs "$@"' > /usr/local/bin/snarkjs && \
    chmod +x /usr/local/bin/snarkjs

ENV PATH=/usr/local/bin:$PATH

USER node

CMD ["snarkjs", "--help"]
