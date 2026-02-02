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
# Builder Stage: Install build-time tools (Foundry, Circom)
# ============================================================================
FROM base AS builder

WORKDIR /tmp

# Install Foundry (Cast, Forge, Anvil) with version pinning
ENV FOUNDRY_VERSION=nightly
SHELL ["/bin/bash", "-c"]
RUN curl -L https://foundry.paradigm.xyz | bash && \
    /root/.foundry/bin/foundryup --version ${FOUNDRY_VERSION}

# Install Circom (pre-built binary for faster builds)
RUN curl -L -o /usr/local/bin/circom \
    https://github.com/iden3/circom/releases/download/v2.1.8/circom-linux-amd64 && \
    chmod +x /usr/local/bin/circom

# ============================================================================
# Runtime Stage: Minimal production image
# ============================================================================
FROM base AS runtime

# Copy Foundry binaries from builder stage
COPY --from=builder /root/.foundry/bin/* /usr/local/bin/

# Copy Circom from builder stage
COPY --from=builder /usr/local/bin/circom /usr/local/bin/circom

# Set working directory
WORKDIR /app

# Copy dependency manifests first (leverage Docker layer caching)
COPY --chown=node:node package*.json ./
COPY --chown=node:node foundry.toml ./

# Install Node.js dependencies (production only)
RUN npm install --omit=dev && npm cache clean --force

# Copy project files
COPY --chown=node:node . .

# Make all scripts executable
RUN chmod +x bin/*.sh 2>/dev/null || true

# Switch to non-root user for security
USER node

# Default command: compile circuits (if any) and run tests
CMD ["/bin/bash", "-c", "./bin/compile_circuit.sh && forge test -vv"]
