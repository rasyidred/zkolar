# Zkolar

**Zero-Knowledge Academic Credential Protocol**

A privacy-preserving academic credential system using ZK-SNARKs (Groth16) to prove academic qualifications without revealing raw data like actual grades.

## Overview

Zkolar enables students to prove their academic achievements (e.g., "My GPA is above 3.5") to employers or institutions without revealing the exact GPA. The system uses Circom circuits for zero-knowledge proofs and Solidity smart contracts for on-chain verification.

### Key Features

- 🔒 **Privacy-Preserving** - Prove qualifications without revealing sensitive data
- ⚡ **ZK-SNARK Proofs** - Efficient Groth16 proof system
- 🔗 **On-Chain Verification** - Ethereum smart contracts verify proofs
- 🛠️ **Automated Workflow** - Complete circuit compilation and proof generation pipeline
- 🐳 **Docker Support** - Containerized development environment

## Architecture

```
Zkolar/
├── circuits/           # Off-chain privacy logic (Circom circuits)
│   ├── grade_check.circom  # GPA threshold verification circuit
│   ├── grade_check.json    # Circuit inputs
│   └── build/          # Compiled artifacts (gitignored)
│
├── bin/                # Automation scripts
│   └── compile_circuit.sh  # Circuit compilation & Verifier generation
│
├── src/                # On-chain verification (Solidity contracts)
│   ├── Counter.sol     # Example contract
│   └── *Verifier.sol   # Auto-generated per circuit (do not edit!)
│
├── script/             # Foundry deployment scripts
├── test/               # Foundry tests
└── lib/                # Dependencies
```

### How It Works

1. **Circuit Compilation** (`circuits/`) - Define privacy constraints in Circom
2. **Proof Generation** - User generates proofs locally with private inputs
3. **On-Chain Verification** (`src/`) - Smart contracts verify proofs on Ethereum

## Prerequisites

- Docker

## Quick Start

```bash
docker build --build-arg POWER_OF_TAU=15 -t zkolar .
docker run zkolar
```

**What `docker run zkolar` does:**
1. Auto-install dependencies (forge-std, openzeppelin-contracts)
2. Compile circuits → Generate `src/GradeCheckVerifier.sol`
3. Run Foundry tests

**With volume mounts (Windows):**
```bash
docker run -v "${PWD}/src:/app/src" -v "${PWD}/circuits:/app/circuits" zkolar
```

## Adding Dependencies (Maintainers Only)

**For maintainers** adding new libraries to the project:

```bash
git submodule add https://github.com/OpenZeppelin/openzeppelin-contracts lib/openzeppelin-contracts
docker build -t zkolar .
```

**For users** cloning the repo: No action needed - all dependencies are included and auto-installed.

## Manual Commands

### Compile Circuit → Generate Verifier
```bash
docker run zkolar ./bin/compile_circuit.sh
```
Output: `src/GradeCheckVerifier.sol` (circuit-specific naming)

### Compile Solidity Contracts
```bash
docker run zkolar forge build
```

### Run Tests
```bash
docker run zkolar forge test -vv
```

## Development Workflow

### 1. Create a Circuit

Create a new `.circom` file in `circuits/`:

```circom
pragma circom 2.1.8;

include "circomlib/circuits/comparators.circom";
include "circomlib/circuits/poseidon.circom";

template GradeCheck() {
    signal input gpa;            // Private: actual GPA (0-100 scale)
    signal input salt;           // Private: random salt for commitment
    signal input threshold;      // Public: minimum required GPA
    signal input identityHash;   // Public: Poseidon(gpa, salt) commitment

    signal output valid;

    // Range proof: gpa >= threshold (7-bit inputs, max 128)
    component greaterThan = GreaterEqThan(7);
    greaterThan.in[0] <== gpa;
    greaterThan.in[1] <== threshold;
    valid <== greaterThan.out;

    // Commitment verification: prove gpa matches the committed hash
    component hasher = Poseidon(2);
    hasher.inputs[0] <== gpa;
    hasher.inputs[1] <== salt;
    hasher.out === identityHash;
}

component main = GradeCheck();
```

### 2. Create Input File

Create a corresponding `.json` file with test inputs:

```json
{
  "gpa": "80",
  "salt": "303",
  "threshold": "75",
  "identityHash": "8364575429015195121375240014522732930319688692600484555979591744514770520990"
}
```

Note: The `identityHash` must equal `Poseidon(gpa, salt)`. Use a Poseidon hash calculator to compute this value.

### 3. Compile Circuit

```bash
./bin/compile_circuit.sh circuits/grade_check.circom
```

### 4. Use Verifier in Solidity

The auto-generated verifier contract uses circuit-specific naming (e.g., `GradeCheckVerifier.sol`):

```solidity
import "./GradeCheckVerifier.sol";

contract Zkolar {
    GradeCheckVerifier public verifier;

    constructor() {
        verifier = new GradeCheckVerifier();
    }

    function verifyCredential(
        uint[2] memory a,
        uint[2][2] memory b,
        uint[2] memory c,
        uint[2] memory input  // [valid, identityHash]
    ) public view returns (bool) {
        return verifier.verifyProof(a, b, c, input);
    }
}
```

### 5. Write Tests

Create Foundry tests in `test/`:

```solidity
contract ZkolarTest is Test {
    Zkolar public zkolar;

    function setUp() public {
        zkolar = new Zkolar();
    }

    function testVerifyValidProof() public {
        // Load proof from circuits/build/
        // Test verification
        assertTrue(zkolar.verifyCredential(a, b, c, input));
    }
}
```

## Project Structure

### circuits/
Contains Circom circuit definitions and build artifacts.
- Write circuits in `.circom` files
- Provide inputs in `.json` files
- Build artifacts auto-generated in `build/`

### bin/
Automation scripts for development workflow.
- `compile_circuit.sh` - Complete circuit compilation pipeline

### src/
Solidity smart contracts.
- `*Verifier.sol` - Auto-generated per circuit (e.g., `GradeCheckVerifier.sol`), do not edit manually
- Add your application logic contracts here

### script/
Foundry deployment scripts.

### test/
Foundry test files.

## Configuration

### Powers of Tau

Default power of tau: 15 (supports up to ~32k constraints)

Change with `-t` flag:
```bash
./bin/compile_circuit.sh -t 18 circuits/grade_check.circom
```

When building Docker, match the power of tau:
```bash
docker build --build-arg POWER_OF_TAU=18 -t zkolar .
```

### Trusted Setup

The script uses single-contributor trusted setup (adequate for development).

For production, perform a multi-party ceremony:
```bash
snarkjs zkey contribute circuit_0000.zkey circuit_0001.zkey \
  --name="Contributor 1" -v -e="random entropy"
```

## Troubleshooting

### Command not found: circom
Install Circom (see Prerequisites section)

### Command not found: snarkjs
```bash
npm install
```

### Docker build fails
Ensure Docker has sufficient memory (≥4GB recommended)

### Proof verification fails
- Check input values match circuit constraints
- Verify circuit compilation completed successfully
- Ensure the verifier contract is up-to-date (recompile circuit)

## Best Practices

✅ **Use snarkjs for witness generation** - Standard workflow
✅ **Git-ignore build artifacts** - Large files (.zkey, .wasm, .ptau, etc.)
✅ **Never edit *Verifier.sol manually** - Auto-generated files
✅ **Keep circuits simple** - Easier to audit and debug
✅ **Test thoroughly** - ZK bugs are hard to detect
✅ **Use circuit-specific verifier names** - Prevents collisions when compiling multiple circuits

## Resources

- [Circom Documentation](https://docs.circom.io/)
- [snarkjs Documentation](https://github.com/iden3/snarkjs)
- [Foundry Book](https://book.getfoundry.sh/)
- [ZK-SNARKs Explained](https://z.cash/technology/zksnarks/)

## Architecture Document

For detailed architecture and development guidelines, see [guideline.md](guideline.md).

## License

[Add your license here]

## Contributing

[Add contribution guidelines here]

---

Built with ❤️ using Circom, snarkjs, and Foundry.
