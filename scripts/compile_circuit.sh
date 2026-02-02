#!/bin/bash
set -e

CIRCUIT_DIR="circuits"
BUILD_DIR="$CIRCUIT_DIR/build"
CIRCUIT_NAME="grade_check"

echo "🔧 Compiling Circom circuit..."

# Create build directory
mkdir -p "$BUILD_DIR"

# Check if circuit file exists
if [ ! -f "$CIRCUIT_DIR/$CIRCUIT_NAME.circom" ]; then
    echo "⚠️  No circuit file found at $CIRCUIT_DIR/$CIRCUIT_NAME.circom"
    echo "Skipping circuit compilation..."
    exit 0
fi

# Compile circuit
circom "$CIRCUIT_DIR/$CIRCUIT_NAME.circom" \
    --r1cs \
    --wasm \
    --sym \
    -o "$BUILD_DIR"

# Generate Verifier.sol using SnarkJS
echo "📝 Generating Verifier.sol..."
node_modules/.bin/snarkjs zkey export solidityverifier \
    "$BUILD_DIR/${CIRCUIT_NAME}_0001.zkey" \
    "src/Verifier.sol"

echo "✅ Circuit compilation complete!"
