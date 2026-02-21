# Zkolar

**Zero-Knowledge Academic Credential Protocol**

A privacy-preserving academic credential system using ZK-SNARKs (Groth16) to prove academic qualifications without revealing raw data like actual grades.

## What is Zkolar?

Zkolar enables students to prove their academic achievements (e.g., "My GPA is above 3.5") to employers or institutions without revealing the exact GPA. The system uses:

- **Circom circuits** for zero-knowledge proof logic
- **Groth16 protocol** for efficient ZK-SNARK proofs
- **Solidity smart contracts** for on-chain verification
- **Docker** for consistent development environment

### How It Works

```
[Student]              [Circuit]           [Blockchain]
   |                      |                     |
   | Private Inputs:      |                     |
   | - GPA: 3.80          |                     |
   | - Salt: 12345        |                     |
   |                      |                     |
   |------ Prove -------->|                     |
   |                      |                     |
   |      [Witness Gen]   |                     |
   |      [ZK Proof Gen]  |                     |
   |                      |                     |
   |<----- Proof ---------|                     |
   |                      |                     |
   |----------- Submit Proof to Verifier ------>|
   |                      |                     |
   |                      |      [Smart Contract]
   |                      |      [Verify Proof]
   |                      |      [Return: valid=1]
   |                      |                     |
   |<---------- Verification Result ------------|
   |                      |                     |
  ✅ Proved GPA ≥ 3.5             🔒 Actual GPA stays private
```

### Key Features

- 🔒 **Privacy-Preserving** - Prove qualifications without revealing sensitive data
- ⚡ **Efficient** - Groth16 proofs are small (~200 bytes) and fast to verify
- 🔗 **On-Chain Verification** - Ethereum smart contracts verify proofs
- 🐳 **Docker Support** - Containerized development environment
- 🛠️ **Automated Workflow** - Make commands handle complex operations

---

## Quick Start

### Prerequisites

- **Docker Desktop** 4.0+ (Windows/Mac) or **Docker Engine** 20.10+ (Linux)
- **Git** 2.0+
- **Hardware**: 8GB+ RAM, 10GB+ disk space

### 5-Minute Setup

```bash
# 1. Clone repository
git clone https://github.com/your-org/zkolar.git
cd zkolar

# 2. Initialize environment (downloads dependencies, ~2 min)
make init

# 3. Run full workflow (compile circuits → generate proofs → test)
make full
```

### Expected Output

```
=========================================
Full workflow complete!
=========================================

Ran 4 tests for test/Zkolar.t.sol:ZkolarTest
[PASS] testBelowThresholdCase() (gas: 204882)
[PASS] testContractSetup() (gas: 9909)
[PASS] testHappyCase() (gas: 204964)
[PASS] testInvalidProof() (gas: 1024173781)
Suite result: ok. 4 passed; 0 failed
```

✅ **Success!** Your Zkolar system is working.

---

## Workflows

### Overview

```
┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│   COMPILE    │ ───> │    PROVE     │ ───> │     TEST     │
│   circuits   │      │  generate    │      │   Foundry    │
│              │      │   proofs     │      │    tests     │
└──────────────┘      └──────────────┘      └──────────────┘
      |                      |                      |
      v                      v                      v
 Verifier.sol          proof.json           All tests pass
```

### 1. Circuit Compilation (`make compile`)

**What It Does**:

1. Compiles `grade_check.circom` → R1CS constraint system
2. Performs trusted setup (generates proving & verification keys)
3. Exports verification key to Solidity contract

**Circuit Statistics** (`grade_check`):

| Metric | Value |
|--------|-------|
| Constraints | 250 |
| Wires | 253 |
| Private Inputs | 4 (`gpa`, `salt`, `threshold`, `identityHash`) |
| Public Inputs | 0 |
| Outputs | 1 (`valid`) |

These values are displayed automatically during compilation via `snarkjs r1cs info`.

**Process Flow**:

```
[grade_check.circom]
        |
        v
   [Circom Compiler]
        |
        v
   [R1CS + WASM]
        |
        v
  [Trusted Setup]
        |
        ├──> [Proving Key (.zkey)]         143KB
        ├──> [Verification Key (.json)]    ~2KB
        └──> [Solidity Verifier (.sol)]    ~10KB
```

**Input Files**:

- [circuits/grade_check.circom](circuits/grade_check.circom) - Circuit definition
- [circuits/grade_check.json](circuits/grade_check.json) - Test inputs

**Output Files**:

- `circuits/build/grade_check_*_final.zkey` - Proving key
- `circuits/build/grade_check_js/grade_check.wasm` - Witness generator
- `circuits/build/grade_check_*_verification_key.json` - Verification key
- [src/GradeCheckVerifier.sol](src/GradeCheckVerifier.sol) - Auto-generated verifier

**Duration**: ~30-60 seconds

**Command**:

```bash
make compile
```

### 2. Proof Generation (`make prove`)

**What It Does**:
Generates ZK proofs for three test cases:

1. **happy_case**: GPA 3.80 ≥ 3.50 → `valid=1`
2. **fail_case**: GPA 3.20 < 3.50 → `valid=0`
3. **invalid_case**: Manipulated inputs → verification fails

**Process Flow**:

```
[Test Input]               [Proving Key]
  GPA: 380                    (.zkey)
  Salt: 12345                    |
  Threshold: 350                 |
      |                          |
      v                          v
[Witness Generator]  +  [Proof Generator]
  (grade_check.wasm)        (snarkjs)
      |                          |
      v                          v
  [Witness]           →    [ZK Proof]
   (.wtns)                  (.json)
                                |
                                v
                          [Public Signals]
                            valid: 1
```

**Input Files**:

- [circuits/test_inputs/happy_case.json](circuits/test_inputs/happy_case.json)
- [circuits/test_inputs/fail_case.json](circuits/test_inputs/fail_case.json)
- [circuits/test_inputs/invalid_case.json](circuits/test_inputs/invalid_case.json)

**Output Files**:

- `circuits/test_proofs/happy_case_proof.json` - Proof
- `circuits/test_proofs/happy_case_public.json` - Public signals
- (Same for fail_case and invalid_case)

**Duration**: ~5-10 seconds

**Command**:

```bash
make prove
```

### 3. Testing (`make test`)

**What It Does**:
Runs Foundry tests that verify proofs on-chain:

| Test                     | Description                 | Expected  |
| ------------------------ | --------------------------- | --------- |
| `testContractSetup`      | Verifier deployed correctly | ✅ Pass   |
| `testHappyCase`          | GPA 3.80 ≥ 3.50, valid=1    | ✅ Verify |
| `testBelowThresholdCase` | GPA 3.20 < 3.50, valid=0    | ✅ Verify |
| `testInvalidProof`       | Manipulated proof data      | ❌ Reject |

**Process**:

1. Deploy [src/GradeCheckVerifier.sol](src/GradeCheckVerifier.sol) to test EVM
2. Submit proofs from [circuits/test_proofs/](circuits/test_proofs/)
3. Verify results match expectations

**Duration**: ~5 seconds

**Command**:

```bash
make test
```

### 4. Full Workflow (`make full`)

Runs all three steps sequentially:

```bash
make compile  # Compile circuits
make prove    # Generate proofs
make test     # Run tests
```

**Command**:

```bash
make full
```

---

## Make Commands Reference

### First-Time Setup

```bash
make init
```

**Purpose**: Initialize environment (run ONCE when first setting up)

**What It Does**:

- Creates Docker volumes for caching
- Downloads Powers of Tau file (ptau_files/powersOfTau28_hez_final_15.ptau)
- Installs Foundry dependencies (forge-std, openzeppelin-contracts)

**Duration**: ~2 minutes

**When to Use**: First time only

---

### Development Workflow

```bash
make compile
```

**Purpose**: Compile circuits → generate verifier contract

**What It Does**:

- Compiles [circuits/grade_check.circom](circuits/grade_check.circom)
- Generates proving/verification keys
- Creates [src/GradeCheckVerifier.sol](src/GradeCheckVerifier.sol)

**When to Use**:

- After modifying circuit files
- After modifying circuit inputs
- When verifier contract is missing

---

```bash
make prove
```

**Purpose**: Generate ZK proofs for test cases

**What It Does**:

- Generates proofs for all test cases
- Outputs to `circuits/test_proofs/`

**When to Use**:

- After running `make compile`
- After modifying test inputs
- When proof files are missing

---

```bash
make test
```

**Purpose**: Run Foundry tests

**What It Does**:

- Deploys verifier contract to test EVM
- Runs all 4 tests in [test/Zkolar.t.sol](test/Zkolar.t.sol)
- Reports gas usage

**When to Use**:

- After running `make prove`
- After modifying smart contracts
- To verify everything works

---

```bash
make full
```

**Purpose**: Full workflow (compile → prove → test)

**What It Does**:
Runs sequentially:

1. `make compile`
2. `make prove`
3. `make test`

**When to Use**:

- Standard development workflow
- After any circuit/contract changes
- To verify end-to-end functionality

---

### Utilities

```bash
make dev
```

**Purpose**: Interactive shell with all tools

**What It Does**:

- Launches bash shell inside development container
- Provides access to: `circom`, `snarkjs`, `forge`, `cast`, `anvil`

**When to Use**:

- Manual debugging
- Running custom commands
- Exploring generated files

**Example Usage**:

```bash
make dev
# Inside container:
circom --version
snarkjs --version
forge --version
ls circuits/build/
```

---

```bash
make clean
```

**Purpose**: Remove Docker containers and volumes

**What It Does**:

- Stops all containers
- Removes Docker volumes (node_modules, lib, cache, out)
- **Does NOT** delete circuit build artifacts or proofs

**When to Use**:

- Fresh start needed
- Disk space cleanup
- After major Docker changes

**Note**: Run `make init` after `make clean` to reinitialize

---

```bash
make help
```

**Purpose**: Show all available commands

**What It Does**:

- Displays all make commands with descriptions

---

## Interactive Playground

Zkolar includes an interactive playground for experimenting with custom GPA values and generating proofs dynamically.

### Quick Start

```bash
make playground
```

### What It Does

1. **Prompts for inputs**: Enter GPA, salt, and threshold interactively
2. **Computes identity hash**: Automatically calculates Poseidon(GPA, salt)
3. **Generates test input**: Creates `circuits/test_inputs/custom_case.json`
4. **Creates ZK proof**: Uses Docker + snarkjs to generate proof
5. **Verifies proof**: Off-chain verification with instant results
6. **Exports Solidity code**: Copy-paste ready for tests

### Example Session

```
🎓 Zkolar Interactive Playground

📝 Existing test cases for reference:
  - happy_case: GPA 3.80, salt 12345, threshold 3.50 → PASS (meetsThreshold=1)
  - fail_case: GPA 3.20, salt 67890, threshold 3.50 → FAIL (meetsThreshold=0)

? Enter GPA (0.00-4.00): 3.75
? Enter salt (random number): 54321
? Enter threshold GPA (e.g., 3.50): 3.50

✅ Identity Hash: 19876543210987654321098765432109876543210987654321098765432109876
  Computed as: Poseidon(375, 54321)

✅ Test input saved: circuits/test_inputs/custom_case.json
{
  "gpa": "375",
  "salt": "54321",
  "threshold": "350",
  "identityHash": "19876543210987654321098765432109876543210987654321098765432109876"
}

✅ ZK proof generated successfully! ✨
  Output: circuits/test_proofs/custom_case_proof.json

✅ Proof verified successfully!

📊 GPA Check Result:
   meetsThreshold = 1

   ✅ PASS: GPA meets or exceeds the threshold

   Note: The proof is cryptographically valid in both cases.
   The proof proves the correctness of the threshold check result.

📋 Solidity Calldata Export

? Export Solidity calldata format? Yes

✅ Solidity calldata generated!

📄 Copy this into your Solidity test:
────────────────────────────────────────
["0x...", "0x..."], [["0x...", "0x..."], ["0x...", "0x..."]], ["0x...", "0x..."], ["0x1"]
────────────────────────────────────────
```

### Files Created

| File                                           | Purpose                     |
| ---------------------------------------------- | --------------------------- |
| `circuits/test_inputs/custom_case.json`        | Your custom input values    |
| `circuits/test_proofs/custom_case_proof.json`  | Generated ZK proof          |
| `circuits/test_proofs/custom_case_public.json` | Public signals (valid flag) |

### Advanced: Add Custom Test

After generating proof, add it to your test suite:

1. **Copy proof values** from playground export
2. **Add to [test/Zkolar.t.sol](test/Zkolar.t.sol)**:

```solidity
function testCustomCase() public view {
    // Proof values from playground
    uint256[2] memory a = [uint256(0x...), uint256(0x...)];
    uint256[2][2] memory b = [
        [uint256(0x...), uint256(0x...)],
        [uint256(0x...), uint256(0x...)]
    ];
    uint256[2] memory c = [uint256(0x...), uint256(0x...)];
    uint256[1] memory publicSignals = [uint256(1)];

    bool result = zkolar.verifyCredential(a, b, c, publicSignals);
    assertTrue(result, "Custom case should verify");
}
```

3. **Run tests**:

```bash
make test
```

### Use Cases

- **Experiment with edge cases**: Test GPA values near the threshold
- **Demo zero-knowledge**: Show how proofs work without revealing exact GPA
- **Generate test data**: Create multiple test cases quickly
- **Learning tool**: Understand the full ZK workflow interactively

### Requirements

- Circuits must be compiled first: `make compile`
- Docker must be running
- Node.js dependencies installed automatically on first run

---

## Troubleshooting

### Docker Issues

#### "Array with zero length specified" or old files in container

**Cause**: Using wrong Docker command or stale image

**Wrong Command**:

```bash
docker run zkolar forge build  # ❌ Uses old cached image
```

**Correct Command**:

```bash
docker compose run --rm test forge build  # ✅ Uses current source code
# OR
make test  # ✅ Recommended - uses correct Docker Compose service
```

**If problem persists**: Rebuild images

```bash
docker compose build --no-cache
```

**Note**: There is no standalone `zkolar:latest` image. Always use Docker Compose services (`zkolar:dev`, `zkolar:ci`, `zkolar:prod`) via `make` commands or `docker compose run`.

---

#### "Docker daemon not running"

**Windows/Mac**:

1. Open Docker Desktop
2. Wait for "Docker Desktop is running" status

**Linux**:

```bash
sudo systemctl start docker
sudo systemctl status docker
```

---

#### "Cannot connect to Docker daemon"

```bash
# Verify Docker is running:
docker ps

# If fails, restart Docker:
# Windows/Mac: Restart Docker Desktop
# Linux: sudo systemctl restart docker
```

---

#### "Permission denied" (Linux only)

```bash
# Add user to docker group:
sudo usermod -aG docker $USER

# Log out and back in, then test:
docker ps  # Should work without sudo
```

---

#### "No space left on device"

```bash
# Clean up Docker system:
docker system prune -a --volumes

# Check freed space:
docker system df
```

---

### Build Issues

#### "Invalid witness length: Circuit: 250, witness: 534"

**Cause**: Zkey and WASM from different compilations (artifact mismatch)

**Solution**:

```bash
# Clean and regenerate:
make clean
rm -rf circuits/build/*_final.zkey circuits/build/*_js/
make full
```

---

#### "ecpairing precompile error" during tests

**Cause**: Proof format mismatch (b array ordering)

**Status**: ✅ Fixed in [test/Zkolar.t.sol](test/Zkolar.t.sol)

**Verification**:

```bash
make dev
# Inside container:
snarkjs groth16 verify \
  circuits/build/grade_check_*_verification_key.json \
  circuits/test_proofs/happy_case_public.json \
  circuits/test_proofs/happy_case_proof.json
# Should output: [INFO] snarkJS: OK!
```

---

### Windows-Specific Issues

#### "Line ending errors" in bash scripts

**Status**: ✅ Fixed - dos2unix auto-runs during build

**Symptoms**:

```
./bin/compile_circuit.sh: line 2: $'\r': command not found
```

**Solution**: Already handled in Dockerfile

---

#### "Volume mount not working"

```bash
# Check Docker Desktop file sharing:
# 1. Docker Desktop → Settings → Resources → File Sharing
# 2. Add project path: d:\Projects\zkolar
# 3. Apply & Restart

# Test mounting:
make dev
ls circuits/  # Should show your circuit files
```

---

#### "Slow performance on Windows"

```bash
# Enable WSL 2 backend (10x faster):
# 1. Docker Desktop → Settings → General
# 2. Enable "Use the WSL 2 based engine"
# 3. Apply & Restart

# Verify WSL 2:
docker info | grep "Operating System"
# Should show: Operating System: Docker Desktop (WSL 2)
```

---

### Test Failures

#### All tests fail: "Verifier address should match"

**Cause**: Verifier contract not generated

**Solution**:

```bash
# Check if verifier exists:
ls src/GradeCheckVerifier.sol

# If missing, recompile:
make compile

# Verify it contains contract:
grep "contract GradeCheckVerifier" src/GradeCheckVerifier.sol
```

---

#### "Proof should verify successfully" fails

**Solution**:

```bash
# 1. Check artifacts exist:
ls circuits/build/grade_check_*_final.zkey
ls circuits/build/grade_check_js/grade_check.wasm
ls src/GradeCheckVerifier.sol

# 2. Check proofs generated:
ls circuits/test_proofs/happy_case_proof.json

# 3. Regenerate everything:
make clean
make full
```

---

## Project Structure

```
zkolar/
├── circuits/               # Off-chain privacy logic
│   ├── grade_check.circom   # Circuit definition
│   ├── grade_check.json     # Test inputs
│   ├── build/               # Compiled artifacts (gitignored)
│   ├── test_inputs/         # Proof generation inputs
│   └── test_proofs/         # Generated proofs
│
├── bin/                    # Automation scripts
│   ├── compile_circuit.sh   # Circuit compilation pipeline
│   └── generate_test_proofs.sh  # Proof generation
│
├── src/                    # On-chain verification
│   ├── Zkolar.sol           # Main contract
│   └── GradeCheckVerifier.sol  # Auto-generated (do not edit!)
│
├── test/                   # Foundry tests
│   └── Zkolar.t.sol         # Test suite
│
├── lib/                    # Dependencies (gitignored)
│   ├── forge-std/
│   └── openzeppelin-contracts/
│
├── Dockerfile              # Multi-stage build (6 stages)
├── docker-compose.yml      # Service definitions (5 services)
├── Makefile               # Developer shortcuts
└── README.md              # This file
```

---

## GPA Encoding System

**Challenge**: Circom circuits only support integers, but GPAs use decimals (3.75)

**Solution**: Fixed-point arithmetic (multiply by 100)

**Encoding**:
| Display GPA | Internal Value | Explanation |
|-------------|----------------|-------------|
| 0.00 | 0 | Minimum |
| 2.50 | 250 | Below threshold |
| 3.50 | 350 | Threshold |
| 3.80 | 380 | Above threshold |
| 4.00 | 400 | Maximum |

**Example**:

```
User Input:   GPA = 3.80
Encode:       3.80 × 100 = 380
Circuit Check: 380 >= 350 ? YES
Output:       valid = 1
```

---

## Deployment

### Local Deployment (Anvil)

```bash
# Terminal 1: Start local testnet
make anvil

# Terminal 2: Deploy contracts
docker compose run --rm dev forge script script/Zkolar.s.sol \
  --rpc-url http://anvil:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast
```

### Testnet Deployment

```bash
# Deploy to Sepolia
docker compose run --rm dev forge script script/Zkolar.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

**For detailed deployment instructions**, see [script/README.md](script/README.md).

---

## Resources

- [Circom Documentation](https://docs.circom.io/)
- [snarkjs Documentation](https://github.com/iden3/snarkjs)
- [Foundry Book](https://book.getfoundry.sh/)
- [ZK-SNARKs Explained](https://z.cash/technology/zksnarks/)

---

## License

[Add your license here]

---

Built with ❤️ using Circom, snarkjs, and Foundry.
