# syntax=docker/dockerfile:1.4

# ============================================================================
# Base Stage: Common dependencies for all stages
# ============================================================================
FROM node:20-bookworm-slim AS base

# Metadata
LABEL maintainer="zkolar"
LABEL description="Zero-Knowledge Grade Verification System"
LABEL version="1.0.0"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    build-essential \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Use existing node user (UID 1000) for security
# The node:20-bookworm-slim image already has a 'node' user with UID 1000

# ============================================================================
# Foundry Stage: Get Foundry binaries from official image
# ============================================================================
FROM ghcr.io/foundry-rs/foundry:latest AS foundry

# ============================================================================
# Builder Stage: Install build-time tools (Circom)
# ============================================================================
FROM base AS builder

WORKDIR /tmp

# Install Circom (pre-built binary for faster builds)
RUN curl -L -o /usr/local/bin/circom \
    https://github.com/iden3/circom/releases/download/v2.1.8/circom-linux-amd64 && \
    chmod +x /usr/local/bin/circom

# ============================================================================
# Runtime Stage: Minimal production image
# ============================================================================
FROM base AS runtime

# Copy Foundry binaries from official Foundry image
COPY --from=foundry /usr/local/bin/forge /usr/local/bin/forge
COPY --from=foundry /usr/local/bin/cast /usr/local/bin/cast
COPY --from=foundry /usr/local/bin/anvil /usr/local/bin/anvil
COPY --from=foundry /usr/local/bin/chisel /usr/local/bin/chisel
RUN chmod +x /usr/local/bin/forge /usr/local/bin/cast /usr/local/bin/anvil /usr/local/bin/chisel

# Copy Circom from builder stage
COPY --from=builder /usr/local/bin/circom /usr/local/bin/circom

# Set PATH to ensure all binaries are accessible
ENV PATH=/usr/local/bin:$PATH

# Suppress nightly build warning (optional)
ENV FOUNDRY_DISABLE_NIGHTLY_WARNING=1

# Set working directory
WORKDIR /app

# Copy dependency manifests first (leverage Docker layer caching)
COPY --chown=node:node package*.json ./
COPY --chown=node:node foundry.toml ./

# Install Node.js dependencies including snarkjs
RUN npm install --omit=dev && \
    npm install -g snarkjs && \
    npm cache clean --force

# Copy Foundry dependencies (lib/) before copying project files
# This ensures forge-std and other dependencies are available
COPY --chown=node:node lib/ ./lib/

# Copy project files
COPY --chown=node:node . .

# Fix line endings and make scripts executable
RUN apt-get update && apt-get install -y dos2unix && \
    find bin -type f -name "*.sh" -exec dos2unix {} \; && \
    chmod +x bin/*.sh && \
    apt-get remove -y dos2unix && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* 2>/dev/null || true

# Create output directories with correct permissions for node user
RUN mkdir -p out cache && chown -R node:node out cache

# Switch to non-root user for security
USER node

# Default command: install dependencies, compile circuits, and run tests
CMD ["/bin/bash", "-c", "./bin/install_foundry_deps.sh && ./bin/compile_circuit.sh && echo 'Running Foundry tests...' && forge test -vv"]
