#!/bin/bash
# Complete end-to-end: compile circuit, generate proofs, display for copying into tests

set -e

echo "=== Step 1: Compiling circuit ==="
./bin/compile_circuit.sh circuits/grade_check.circom

echo ""
echo "=== Step 2: Generating test proofs ==="
./bin/generate_test_proofs.sh

echo ""
echo "=== Step 3: Proof data for Solidity tests ==="
echo ""

for TEST_CASE in "happy_case" "fail_case"; do
    echo "// ===== ${TEST_CASE} ====="
    PROOF_FILE="circuits/test_proofs/${TEST_CASE}_proof.json"
    PUBLIC_FILE="circuits/test_proofs/${TEST_CASE}_public.json"

    # exportsoliditycalldata handles hex formatting and b-array swapping
    # Usage: snarkjs zkesc [public.json] [proof.json]
    snarkjs zkey export soliditycalldata \
        "${PUBLIC_FILE}" \
        "${PROOF_FILE}"
    echo ""
done
