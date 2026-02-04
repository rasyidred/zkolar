#!/bin/bash

set -e

CIRCUIT_NAME="grade_check"
CIRCUIT_PATH="circuits/${CIRCUIT_NAME}.circom"
TEST_INPUTS_DIR="circuits/test_inputs"
TEST_PROOFS_DIR="circuits/test_proofs"
BUILD_DIR="circuits/build"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}Generating Test Proofs${NC}"
echo -e "${GREEN}=====================================${NC}"

# Create output directory
mkdir -p "${TEST_PROOFS_DIR}"

# Test cases
TEST_CASES=("happy_case" "fail_case" "invalid_case")

for TEST_CASE in "${TEST_CASES[@]}"; do
    echo -e "${YELLOW}[${TEST_CASE}] Generating proof...${NC}"

    INPUT_FILE="${TEST_INPUTS_DIR}/${TEST_CASE}.json"
    OUTPUT_FILE="${TEST_PROOFS_DIR}/${TEST_CASE}_proof.json"
    PUBLIC_FILE="${TEST_PROOFS_DIR}/${TEST_CASE}_public.json"

    # Find the zkey file (should be in build/)
    ZKEY_FILE=$(find "${BUILD_DIR}" -name "*_final.zkey" | head -n 1)
    WASM_FILE="${BUILD_DIR}/${CIRCUIT_NAME}_js/${CIRCUIT_NAME}.wasm"

    if [ ! -f "${ZKEY_FILE}" ]; then
        echo "Error: zkey file not found. Run compile_circuit.sh first."
        exit 1
    fi

    if [ ! -f "${INPUT_FILE}" ]; then
        echo "Error: Input file not found: ${INPUT_FILE}"
        exit 1
    fi

    # Generate witness
    echo "  Generating witness..."
    node "${BUILD_DIR}/${CIRCUIT_NAME}_js/generate_witness.js" \
        "${WASM_FILE}" \
        "${INPUT_FILE}" \
        "${BUILD_DIR}/${TEST_CASE}_witness.wtns"

    # Generate proof
    echo "  Generating proof..."
    snarkjs groth16 prove \
        "${ZKEY_FILE}" \
        "${BUILD_DIR}/${TEST_CASE}_witness.wtns" \
        "${OUTPUT_FILE}" \
        "${PUBLIC_FILE}"

    echo -e "${GREEN}  ✓ Proof generated: ${OUTPUT_FILE}${NC}"
done

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}✓ All test proofs generated!${NC}"
echo -e "${GREEN}=====================================${NC}"
