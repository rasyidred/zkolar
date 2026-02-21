#!/usr/bin/env bash
#
# Zkolar Circuit Compilation Script
# Compiles Circom circuits and generates Solidity verifier contracts
#

set -euo pipefail

# Configuration
POWER_OF_TAU=15
CIRCUITS_DIR="circuits"
BUILD_DIR="${CIRCUITS_DIR}/build"
SRC_DIR="src"
PTAU_DIR="${BUILD_DIR}/ptau_files"

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Required commands
required_commands=(circom snarkjs curl node)

# Check for required dependencies
for cmd in "${required_commands[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
        echo -e "${RED}\`$cmd\` command could not be found${NC}"
        echo "Please install $cmd before running this script"
        exit 1
    fi
done

# Print usage information
print_usage() {
    echo "Usage: $0 [-t <power>] [-h] [circuit_file ...]"
    echo
    echo "Compiles Circom circuits and generates Solidity verifier contracts"
    echo
    echo "Options:"
    echo "  -t <power>       Power of tau (default: ${POWER_OF_TAU})"
    echo "  -h               Print this usage and exit"
    echo
    echo "Positional Arguments:"
    echo "  circuit_file     Circom circuit file(s) to compile"
    echo "                   If none provided, all circuits in ${CIRCUITS_DIR}/ are compiled"
    echo
    echo "Examples:"
    echo "  $0                                    # Compile all circuits"
    echo "  $0 circuits/grade_check.circom           # Compile specific circuit"
    echo "  $0 -t 20 circuits/grade_check.circom     # Use power of tau 20"
}

# Parse command line options
while getopts ":t:h" opt; do
    case $opt in
        h)
            print_usage
            exit 0
            ;;
        t)
            POWER_OF_TAU="$OPTARG"
            ;;
        :)
            echo -e "${RED}Error: -$OPTARG requires a value${NC}" >&2
            exit 1
            ;;
        \?)
            echo -e "${RED}Error: Invalid option -$OPTARG${NC}" >&2
            exit 1
            ;;
    esac
done

# Shift past the named options to access positional arguments
shift $((OPTIND - 1))

# Construct ptau URL and path based on power of tau
ptau_url="https://storage.googleapis.com/zkevm/ptau/powersOfTau28_hez_final_${POWER_OF_TAU}.ptau"
ptau_path="${PTAU_DIR}/powersOfTau28_hez_final_${POWER_OF_TAU}.ptau"

# Create necessary directories
mkdir -p "$BUILD_DIR"
mkdir -p "$PTAU_DIR"
mkdir -p "$SRC_DIR"

# Download ptau file if it doesn't exist
if [ ! -f "$ptau_path" ]; then
    echo -e "${GREEN}Downloading powers of tau file...${NC}"
    echo "From: $ptau_url"
    echo "To: $ptau_path"
    curl -L "$ptau_url" -o "$ptau_path"
    echo -e "${GREEN}✓ Download complete${NC}"
fi

# Function to compile a single circuit
compile_circuit() {
    local circuit_abs_path=$1    # Absolute path for validation/logging
    local circuit_rel_path=$2    # Relative path for file access

    # For backward compatibility and clarity
    local circuit_path="$circuit_rel_path"

    echo
    echo -e "${GREEN}=====================================${NC}"
    echo -e "${GREEN}Compiling: $circuit_abs_path${NC}"
    echo -e "${GREEN}=====================================${NC}"

    local circuit_name
    circuit_name="$(basename "$circuit_rel_path")" && circuit_name="${circuit_name%%.*}"

    local inputs_path
    inputs_path="$(dirname "$circuit_rel_path")/${circuit_name}.json"

    if [ ! -f "$inputs_path" ]; then
        echo -e "${RED}Error: Inputs file not found at $inputs_path${NC}"
        echo "Expected location: $(dirname "$circuit_abs_path")/${circuit_name}.json"
        echo "Please create an inputs JSON file for your circuit"
        exit 1
    fi

    local witness_path="${BUILD_DIR}/${circuit_name}.wtns"
    local proof_path="${BUILD_DIR}/${circuit_name}_proof.json"
    local public_signals_path="${BUILD_DIR}/${circuit_name}_public.json"
    local r1cs_path="${BUILD_DIR}/${circuit_name}.r1cs"

    # Change to build directory for compilation
    pushd "$BUILD_DIR" >/dev/null

    echo -e "${YELLOW}[1/6] Compiling circuit with circom...${NC}"
    time circom \
        -l ../../node_modules \
        --O2 \
        --sym \
        --r1cs \
        --wasm \
        ../../"$circuit_path"

    # Extract and display circuit info (constraints, inputs, outputs)
    echo -e "${CYAN}Circuit Info:${NC}"
    snarkjs r1cs info "${circuit_name}.r1cs" 2>&1 | grep -E "Constraints|Private|Public|Outputs|Wires"
    echo

    # Calculate MD5 hash of r1cs for zkey naming
    local r1cs_md5
    if command -v md5sum &>/dev/null; then
        r1cs_md5=$(md5sum "${circuit_name}.r1cs" | awk '{print $1}')
    elif command -v openssl &>/dev/null; then
        r1cs_md5=$(openssl dgst -hex -md5 "${circuit_name}.r1cs" | awk '{print $2}')
    else
        # Fallback to timestamp if no hash tool available
        r1cs_md5=$(date +%s)
    fi

    local zkey_path="${circuit_name}_${r1cs_md5}_final.zkey"
    local vk_path="${circuit_name}_${r1cs_md5}_verification_key.json"
    local verifier_path="${circuit_name}_${r1cs_md5}_verifier.sol"

    echo -e "${YELLOW}[2/6] Generating witness...${NC}"
    time node "${circuit_name}"_js/generate_witness.js \
        "${circuit_name}"_js/"${circuit_name}".wasm \
        ../../"${inputs_path}" \
        "${circuit_name}.wtns"

    # Verify witness against r1cs
    snarkjs wtns check "${circuit_name}.r1cs" "${circuit_name}.wtns"

    echo -e "${YELLOW}[3/6] Performing Groth16 trusted setup...${NC}"
    if [ ! -f "$zkey_path" ]; then
        # Initial setup
        snarkjs groth16 setup "${circuit_name}.r1cs" ../../"$ptau_path" "${circuit_name}"_0000.zkey

        # Single contribution (sufficient for development)
        local ENTROPY
        ENTROPY=$(head -c 64 /dev/urandom | od -An -tx1 -v | tr -d ' \n')
        snarkjs zkey contribute \
            "${circuit_name}"_0000.zkey \
            "$zkey_path" \
            --name="1st Contribution" \
            -v \
            -e="$ENTROPY"

        # Verify zkey
        snarkjs zkey verify "${circuit_name}.r1cs" ../../"$ptau_path" "$zkey_path"
        echo -e "${GREEN}✓ Trusted setup complete${NC}"
    else
        echo -e "${GREEN}✓ Using existing zkey: $zkey_path${NC}"
    fi

    echo -e "${YELLOW}[4/6] Exporting verification key...${NC}"
    if [ ! -f "$vk_path" ]; then
        snarkjs zkey export verificationkey "$zkey_path" "$vk_path"
    fi

    echo -e "${YELLOW}[5/6] Generating and verifying proof...${NC}"
    snarkjs groth16 prove "$zkey_path" "${circuit_name}.wtns" "${circuit_name}_proof.json" "${circuit_name}_public.json"
    snarkjs groth16 verify "$vk_path" "${circuit_name}_public.json" "${circuit_name}_proof.json"

    echo -e "${YELLOW}[6/6] Exporting Solidity verifier contract...${NC}"
    snarkjs zkey export solidityverifier "$zkey_path" "$verifier_path"

    # Copy verifier to src/ directory with circuit-specific name
    # Convert circuit name to PascalCase (e.g., grade_check → GradeCheck)
    local verifier_contract_name=$(echo "$circuit_name" | sed -r 's/(^|_)([a-z])/\U\2/g')
    local src_verifier="${SRC_DIR}/${verifier_contract_name}Verifier.sol"

    echo -e "${YELLOW}Generating ${verifier_contract_name}Verifier.sol...${NC}"

    # Update contract name in Solidity file and copy
    sed "s/contract Groth16Verifier/contract ${verifier_contract_name}Verifier/g" "$verifier_path" > ../../"$src_verifier"
    echo -e "${GREEN}✓ Verifier contract copied to ${src_verifier}${NC}"

    popd >/dev/null

    echo -e "${GREEN}=====================================${NC}"
    echo -e "${GREEN}✓ Circuit compilation complete!${NC}"
    echo -e "${GREEN}=====================================${NC}"
    echo
    echo "Outputs:"
    echo "  R1CS:     ${BUILD_DIR}/${circuit_name}.r1cs"
    echo "  WASM:     ${BUILD_DIR}/${circuit_name}_js/${circuit_name}.wasm"
    echo "  Witness:  ${BUILD_DIR}/${circuit_name}.wtns"
    echo "  Zkey:     ${BUILD_DIR}/${zkey_path}"
    echo "  Proof:    ${BUILD_DIR}/${circuit_name}_proof.json"
    echo "  Verifier: ${src_verifier}"
    echo
}

# Main execution
if [ $# -gt 0 ]; then
    # Compile specified circuits
    for arg in "$@"; do
        # Validate with absolute path
        circuit_abs_path=$(realpath "$arg")
        if [ ! -f "$circuit_abs_path" ]; then
            echo -e "${RED}Error: Circuit file not found at $circuit_abs_path${NC}"
            exit 1
        fi

        # Calculate relative path from project root (WORKDIR in Docker is /app)
        # This makes the script work from any location
        project_root=$(pwd)
        circuit_rel_path=$(realpath --relative-to="$project_root" "$circuit_abs_path")

        compile_circuit "$circuit_abs_path" "$circuit_rel_path"
    done
else
    # Compile all circuits in circuits/ directory
    circuit_found=false
    for circuit_file in "$CIRCUITS_DIR"/*.circom; do
        if [ -f "$circuit_file" ]; then
            circuit_found=true
            # Get absolute and relative paths
            circuit_abs_path=$(realpath "$circuit_file")
            project_root=$(pwd)
            circuit_rel_path=$(realpath --relative-to="$project_root" "$circuit_abs_path")
            compile_circuit "$circuit_abs_path" "$circuit_rel_path"
        fi
    done

    if [ "$circuit_found" = false ]; then
        echo -e "${YELLOW}No circuit files found in ${CIRCUITS_DIR}/${NC}"
        echo "Please create a .circom file or specify a circuit file to compile"
        exit 1
    fi
fi

echo -e "${GREEN}All circuits compiled successfully!${NC}"
