# ============================================================================
# Zkolar Makefile
# Zero-Knowledge Grade Verification System
# ============================================================================

.PHONY: help build build-dev build-ci build-prod \
        dev shell compile prove test anvil anvil-bg anvil-stop \
        clean clean-volumes clean-all \
        logs status init full ci playground benchmark

# Default target
.DEFAULT_GOAL := help

# Configuration
DOCKER_COMPOSE := docker compose
POWER_OF_TAU ?= 15

# Detect OS
ifeq ($(OS),Windows_NT)
    # Windows (PowerShell or cmd)
    DETECTED_OS := Windows
    ENV_PASS := -e POWER_OF_TAU=$(POWER_OF_TAU)
else
    # Unix-like (Linux, macOS, WSL)
    UNAME_S := $(shell uname -s)
    ifeq ($(UNAME_S),Linux)
        DETECTED_OS := Linux
    else ifeq ($(UNAME_S),Darwin)
        DETECTED_OS := macOS
    else
        DETECTED_OS := Unix
    endif
    # Unix can use inline env vars
    ENV_PASS :=
endif

# ============================================================================
# Help
# ============================================================================
help:
	@echo "Zkolar Docker Commands"
	@echo "======================"
	@echo ""
	@echo "Build Commands:"
	@echo "  make build          Build all Docker images"
	@echo "  make build-dev      Build development image only"
	@echo "  make build-ci       Build CI image only"
	@echo "  make build-prod     Build production image only"
	@echo ""
	@echo "Development Commands:"
	@echo "  make dev            Start interactive development shell"
	@echo "  make shell          Alias for 'make dev'"
	@echo "  make compile        Compile circuits (ensures artifact consistency)"
	@echo "  make prove          Generate test proofs"
	@echo "  make test           Run Foundry tests"
	@echo "  make playground     Interactive playground for custom proof generation"
	@echo ""
	@echo "Blockchain Commands:"
	@echo "  make anvil          Start local Anvil testnet"
	@echo "  make anvil-bg       Start Anvil in background"
	@echo "  make anvil-stop     Stop Anvil"
	@echo ""
	@echo "Workflow Commands:"
	@echo "  make init           Initialize volumes and dependencies"
	@echo "  make full           Full workflow (compile + prove + test)"
	@echo "  make ci             CI workflow (test only)"
	@echo "  make benchmark      Measure proof generation time and on-chain gas cost"
	@echo ""
	@echo "Utility Commands:"
	@echo "  make logs           View container logs"
	@echo "  make status         Show container status"
	@echo "  make clean          Stop containers and remove images"
	@echo "  make clean-volumes  Remove named volumes"
	@echo "  make clean-all      Full cleanup (containers + volumes + images)"
	@echo ""
	@echo "Environment Variables:"
	@echo "  POWER_OF_TAU        Power of tau for trusted setup (default: 15)"

# ============================================================================
# Build Commands
# ============================================================================
build: build-dev build-ci build-prod
	@echo "All images built successfully"

build-dev:
	@echo "Building development image..."
	$(DOCKER_COMPOSE) build dev

build-ci:
	@echo "Building CI image..."
	$(DOCKER_COMPOSE) build test

build-prod:
	@echo "Building production image..."
	$(DOCKER_COMPOSE) build prove

# ============================================================================
# Development Commands
# ============================================================================
dev: build-dev
	@echo "Starting development environment..."
	$(DOCKER_COMPOSE) run --rm dev

shell: dev

compile: build-dev
	@echo "Compiling circuits on $(DETECTED_OS)..."
	@echo "POWER_OF_TAU=$(POWER_OF_TAU)"
ifeq ($(DETECTED_OS),Windows)
	@$(DOCKER_COMPOSE) run --rm -e POWER_OF_TAU=$(POWER_OF_TAU) compile
else
	@POWER_OF_TAU=$(POWER_OF_TAU) $(DOCKER_COMPOSE) run --rm compile
endif
	@echo ""
	@echo "Artifacts generated in circuits/build/"
	@echo "Verifier contract copied to src/"

prove: build-prod
	@echo "Generating proofs..."
	$(DOCKER_COMPOSE) run --rm prove
	@echo ""
	@echo "Proofs generated in circuits/test_proofs/"

test: build-ci
	@echo "Running Foundry tests..."
	$(DOCKER_COMPOSE) run --rm test

playground:
	@echo "Starting Zkolar Playground..."
	@echo "Installing dependencies (if needed)..."
	@cd playground && npm install --silent
	@echo ""
	@cd playground && node index.js

# ============================================================================
# Blockchain Commands
# ============================================================================
anvil: build-dev
	@echo "Starting Anvil local testnet..."
	$(DOCKER_COMPOSE) up anvil

anvil-bg: build-dev
	@echo "Starting Anvil in background..."
	$(DOCKER_COMPOSE) up -d anvil
	@echo "Anvil running at http://localhost:8545"

anvil-stop:
	$(DOCKER_COMPOSE) stop anvil

# ============================================================================
# Initialization
# ============================================================================
init: build
	@echo "Initializing Zkolar environment..."
	@echo ""
	@echo "Installing Foundry dependencies..."
	$(DOCKER_COMPOSE) run --rm --user root dev bash -c "\
		rm -rf lib/forge-std lib/openzeppelin-contracts && \
		git clone --depth 1 https://github.com/foundry-rs/forge-std lib/forge-std && \
		git clone --depth 1 https://github.com/OpenZeppelin/openzeppelin-contracts lib/openzeppelin-contracts && \
		rm -rf lib/forge-std/.git lib/openzeppelin-contracts/.git && \
		chown -R node:node lib/"
	@echo ""
	@echo "Downloading powers of tau file (this may take a while)..."
	$(DOCKER_COMPOSE) run --rm --user root dev bash -c "\
		mkdir -p circuits/build/ptau_files && \
		chown -R node:node circuits/build && \
		if [ ! -f circuits/build/ptau_files/powersOfTau28_hez_final_$(POWER_OF_TAU).ptau ]; then \
			curl -L https://storage.googleapis.com/zkevm/ptau/powersOfTau28_hez_final_$(POWER_OF_TAU).ptau \
			  -o circuits/build/ptau_files/powersOfTau28_hez_final_$(POWER_OF_TAU).ptau; \
		else \
			echo 'Powers of tau file already exists, skipping download.'; \
		fi"
	@echo ""
	@echo "Initialization complete!"
	@echo "Run 'make compile' to compile circuits."

# ============================================================================
# Utility Commands
# ============================================================================
logs:
	$(DOCKER_COMPOSE) logs -f

status:
	$(DOCKER_COMPOSE) ps -a

# ============================================================================
# Cleanup Commands
# ============================================================================
clean:
	@echo "Stopping containers..."
	$(DOCKER_COMPOSE) down
	@echo "Removing images..."
	docker rmi zkolar:dev zkolar:ci zkolar:prod 2>/dev/null || true
	@echo "Cleanup complete"

clean-volumes:
	@echo "Removing named volumes..."
	docker volume rm zkolar-node-modules zkolar-ptau zkolar-lib \
		zkolar-cache zkolar-out 2>/dev/null || true
	@echo "Volumes removed"

clean-all: clean clean-volumes
	@echo "Full cleanup complete"

# ============================================================================
# Compound Workflows
# ============================================================================
# Full workflow: compile circuits, generate proofs, run tests
full: compile prove test
	@echo ""
	@echo "========================================="
	@echo "Full workflow complete!"
	@echo "========================================="

# CI workflow: test only (assumes artifacts exist)
ci: test
	@echo "CI workflow complete"

# Benchmark: proof generation time + on-chain verification gas
benchmark: compile prove
	@echo ""
	@echo "========================================="
	@echo "On-chain Verification Gas Report"
	@echo "========================================="
	$(DOCKER_COMPOSE) run --rm test forge test --gas-report
