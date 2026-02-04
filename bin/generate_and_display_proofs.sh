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
    
    node -e "
    const fs = require('fs');
    const proof = JSON.parse(fs.readFileSync('${PROOF_FILE}'));
    const pub = JSON.parse(fs.readFileSync('${PUBLIC_FILE}'));
    
    console.log('uint[2] memory a = [');
    console.log('    uint(' + proof.pi_a[0] + '),');
    console.log('    uint(' + proof.pi_a[1] + ')');
    console.log('];');
    console.log('');
    console.log('uint[2][2] memory b = [');
    console.log('    [uint(' + proof.pi_b[0][0] + '),');
    console.log('     uint(' + proof.pi_b[0][1] + ')],');
    console.log('    [uint(' + proof.pi_b[1][0] + '),');
    console.log('     uint(' + proof.pi_b[1][1] + ')]');
    console.log('];');
    console.log('');
    console.log('uint[2] memory c = [');
    console.log('    uint(' + proof.pi_c[0] + '),');
    console.log('    uint(' + proof.pi_c[1] + ')');
    console.log('];');
    console.log('');
    console.log('uint[1] memory publicSignals = [uint(' + pub[0] + ')];');
    console.log('');
    "
    echo ""
done
