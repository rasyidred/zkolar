// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "forge-std/Test.sol";
import "../src/Zkolar.sol";
import "../src/GradeCheckVerifier.sol";

contract ZkolarTest is Test {
    Zkolar public zkolar;
    GradeCheckVerifier public verifier;

    function setUp() public {
        // Deploy verifier contract
        verifier = new GradeCheckVerifier();

        // Deploy Zkolar contract with verifier address
        zkolar = new Zkolar(address(verifier));
    }

    function testContractSetup() public view {
        // Basic unit test: verify verifier address is set correctly
        assertEq(
            address(zkolar.verifier()),
            address(verifier),
            "Verifier address should match"
        );
    }

    function testHappyCase() public view {
        // Test case: GPA 3.80 >= threshold 3.50
        // Expected: valid = 1, verification succeeds
        // Proof values from snarkjs soliditycalldata output (note: b array uses swapped ordering)

        uint256[2] memory a = [
            uint(
                0x067a7f0f1137e14672fd46ae3672ce440fc2bd844087c41d4cd42131a34f7949
            ),
            uint(
                0x118f1b247852c6231a877b7d50bdc94e9e1a4326abb28b9a11d6bcbade731d34
            )
        ];

        uint256[2][2] memory b = [
            [
                uint(
                    0x139af7541dd08a6399b344ba51eeb153239a532b5d066d70b38b77bc2900ab3c
                ),
                uint(
                    0x29051f01120caabae76ab917a9edf97edb30ec7e9890ecfe6268457e0e6db39a
                )
            ],
            [
                uint(
                    0x21a3bda1efa6edb24ebf8100437bcc93182f4352df7a76807355a21ab548c6a4
                ),
                uint(
                    0x26bdf0c483e5950c99867f530b205099d727af663e5173a0f94d39c6de090f2e
                )
            ]
        ];

        uint256[2] memory c = [
            uint(
                0x21b7934496b2b90662547ebfcaf04e2ed5b096fe37afbf786c65c6fa338a7eee
            ),
            uint(
                0x2925f3ad1200256d87b8eb457880c749df4aa4bf7b579ed13ac624be08b7d4b2
            )
        ];

        uint256[1] memory publicSignals = [uint256(1)];

        // Verify the proof
        bool result = zkolar.verifyCredential(a, b, c, publicSignals);
        assertTrue(result, "Happy case: proof should verify successfully");
    }

    function testBelowThresholdCase() public view {
        // Test case: GPA 3.20 < threshold 3.50
        // Expected: valid = 0, but proof still verifies
        // Proof values from snarkjs soliditycalldata output

        uint256[2] memory a = [
            uint(
                0x05e9e75599cec852bcff7eb5fa3ef9f8b9e1b85310413ad1e78d9ee1fce723ba
            ),
            uint(
                0x0417db249f29fdcc445c62591f52e0e8e7fbc1c0d5df98003e27be7f9915dc9c
            )
        ];

        uint256[2][2] memory b = [
            [
                uint(
                    0x0f7214143262b2707a518dd01e321da3bffa4f3fe660626f8a053f923ebaa15c
                ),
                uint(
                    0x0d6a9d289d347c40890ed3515085d0bea632b782091beaf2ca0cd42b16a741c9
                )
            ],
            [
                uint(
                    0x2ff867d00a2d68460d362f06e76de3d4e7e1e5a01d295d9b19f6ad03fe5e0e2b
                ),
                uint(
                    0x2a1289545b1a8aeffb9aef582bd38bb6950baa373d18942f16cf361f0ed674ae
                )
            ]
        ];

        uint256[2] memory c = [
            uint(
                0x2ca7f361c8500cc44c86037851df435f5262fa827885545b87d9cb19ebccad65
            ),
            uint(
                0x07e02cee39be2a704390f00bf5f4330e0b4d2fe3c0f9ac2e8e81a6dd899a0b48
            )
        ];

        uint256[1] memory publicSignals = [uint(0)];

        // Verify the proof - it should still verify because it's cryptographically valid
        bool result = zkolar.verifyCredential(a, b, c, publicSignals);
        assertTrue(
            result,
            "Below threshold case: proof should verify (but valid=0 in public signal)"
        );
    }

    function testInvalidProof() public view {
        // Test case: Manipulated proof data
        // Expected: verification fails

        uint256[2] memory a = [
            uint(
                0x1111111111111111111111111111111111111111111111111111111111111111
            ),
            uint(
                0x2222222222222222222222222222222222222222222222222222222222222222
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

        uint256[1] memory publicSignals = [uint256(1)];

        // Verify the proof - should fail due to manipulated data
        bool result = zkolar.verifyCredential(a, b, c, publicSignals);
        assertFalse(result, "Invalid proof: verification should fail");
    }
}
