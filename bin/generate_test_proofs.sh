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
CYAN='\033[0;36m'
NC='\033[0m'

# Store timing results per case
declare -A PROOF_TIMES

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

    # Find the zkey file for this circuit (should be in build/)
    ZKEY_FILE=$(find "${BUILD_DIR}" -name "${CIRCUIT_NAME}_*_final.zkey" | head -n 1)
    WASM_FILE="${BUILD_DIR}/${CIRCUIT_NAME}_js/${CIRCUIT_NAME}.wasm"

    if [ ! -f "${ZKEY_FILE}" ]; then
        echo "Error: zkey file not found. Run compile_circuit.sh first."
        exit 1
    fi

    if [ ! -f "${INPUT_FILE}" ]; then
        echo "Error: Input file not found: ${INPUT_FILE}"
        exit 1
    fi

    # Generate witness (write to test_proofs since build may be read-only)
    WITNESS_FILE="${TEST_PROOFS_DIR}/${TEST_CASE}_witness.wtns"
    echo "  Generating witness..."
    node "${BUILD_DIR}/${CIRCUIT_NAME}_js/generate_witness.js" \
        "${WASM_FILE}" \
        "${INPUT_FILE}" \
        "${WITNESS_FILE}"

    # Generate proof (timed)
    echo "  Generating proof..."
    PROVE_START=$(date +%s%N)
    snarkjs groth16 prove \
        "${ZKEY_FILE}" \
        "${WITNESS_FILE}" \
        "${OUTPUT_FILE}" \
        "${PUBLIC_FILE}"
    PROVE_END=$(date +%s%N)
    ELAPSED_MS=$(( (PROVE_END - PROVE_START) / 1000000 ))
    PROOF_TIMES["${TEST_CASE}"]=${ELAPSED_MS}

    # Clean up witness file (not needed after proof generation)
    rm -f "${WITNESS_FILE}"

    echo -e "${GREEN}  ✓ Proof generated: ${OUTPUT_FILE}${NC}"
    echo -e "${CYAN}  ⏱ Proof generation time: ${ELAPSED_MS}ms${NC}"
done

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}✓ All test proofs generated!${NC}"
echo -e "${GREEN}=====================================${NC}"
echo
echo -e "${CYAN}Proof Generation Times:${NC}"
for TEST_CASE in "${TEST_CASES[@]}"; do
    printf "  %-15s %sms\n" "${TEST_CASE}:" "${PROOF_TIMES[${TEST_CASE}]}"
done
echo
