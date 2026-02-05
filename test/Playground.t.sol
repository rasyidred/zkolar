// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "forge-std/Test.sol";
import "../src/GradeCheckVerifier.sol";
import "../src/Zkolar.sol";

/**
 * @title Playground Test Suite
 * @notice Interactive playground for testing custom proofs
 * @dev Template test file for adding custom generated proofs
 *
 * Usage:
 * 1. Generate proof via CLI: make playground
 * 2. Copy proof values from output
 * 3. Replace values in testCustomCase()
 * 4. Run: forge test --match-test testCustomCase -vvv
 *
 * Or via Make:
 * $ docker compose run --rm test forge test --match-test testCustomCase -vvv
 */
contract PlaygroundTest is Test {
    GradeCheckVerifier public verifier;
    Zkolar public zkolar;

    function setUp() public {
        verifier = new GradeCheckVerifier();
        zkolar = new Zkolar(address(verifier));
    }

    /// @notice Template test - replace proof values with your generated proof
    /// @dev Get values from: make playground
    function testCustomCase() public view {
        // TODO: Replace these with your generated proof values
        // Copy the Solidity calldata from playground output

        // Default placeholder values (will fail until replaced)
        uint256[2] memory a = [
            uint(
                0x0000000000000000000000000000000000000000000000000000000000000000
            ),
            uint(
                0x0000000000000000000000000000000000000000000000000000000000000000
            )
        ];

        uint256[2][2] memory b = [
            [
                uint(
                    0x0000000000000000000000000000000000000000000000000000000000000000
                ),
                uint(
                    0x0000000000000000000000000000000000000000000000000000000000000000
                )
            ],
            [
                uint(
                    0x0000000000000000000000000000000000000000000000000000000000000000
                ),
                uint(
                    0x0000000000000000000000000000000000000000000000000000000000000000
                )
            ]
        ];

        uint256[2] memory c = [
            uint(
                0x0000000000000000000000000000000000000000000000000000000000000000
            ),
            uint(
                0x0000000000000000000000000000000000000000000000000000000000000000
            )
        ];

        // Change to your expected valid flag (0 or 1)
        uint256[1] memory publicSignals = [uint(0)];

        // Verify the proof
        bool result = zkolar.verifyCredential(a, b, c, publicSignals);

        // Choose assertion based on expected outcome:
        assertTrue(result, "Custom proof should verify");
        // OR: assertFalse(result, "Invalid proof should fail");
    }

    /// @notice Example: Additional custom test slot
    /// @dev You can add multiple custom test cases here
    function testCustomCase2() public view {
        // Add your second custom proof here
        // Follow the same pattern as testCustomCase()

        // Placeholder - will be skipped
        assertTrue(true, "Placeholder test");
    }

    /// @notice Example: Test below threshold case
    /// @dev Template for testing GPA below threshold
    function testCustomBelowThreshold() public view {
        // Use this for testing proofs where GPA < threshold
        // Expected: valid = 0, but proof should still verify

        // Placeholder - will be skipped
        assertTrue(true, "Placeholder test");
    }
}
