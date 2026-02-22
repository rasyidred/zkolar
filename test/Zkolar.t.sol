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
        // Proof values from snarkjs zkey export soliditycalldata

        uint256[2] memory a = [
            uint256(
                0x1d8bc209b034605b2bcd5d971b6b11491c09a6f4cad1c4725f4fcaff015df1ca
            ),
            uint256(
                0x2f3de5136d0ac9046cad16840019b73086c6802e58e106e3703b35e1b8988835
            )
        ];

        uint256[2][2] memory b = [
            [
                uint256(
                    0x11ea48db755c1ed542f2b5452cb25d67d513711966d30c17df31f2942fbecd16
                ),
                uint256(
                    0x2cf448476423d883efc03e1e4e633721dcc3e61d705bf4b254592cbbd776123b
                )
            ],
            [
                uint256(
                    0x2f14929d9dd597b81a2e7a05d4c477ae3388e601593b595cb97ba9ce1a075230
                ),
                uint256(
                    0x28064bb5452d4643e631aef688037e962cb0929f7924f8732f5f8cabb42d82a1
                )
            ]
        ];

        uint256[2] memory c = [
            uint256(
                0x29959d1e55d06cde6852020d8cd849921845e1db82f5937e2f73f5232ac02a13
            ),
            uint256(
                0x255ac7cd7fadd74cecad4d928bdd225e8ba727598cb213abd92dedae16b932cc
            )
        ];

        uint256[1] memory publicSignals = [uint256(1)];

        // Verify the proof
        bool result = zkolar.verifyCredential(a, b, c, publicSignals);
        assertTrue(result, "Happy case: proof should verify successfully");
    }

    function testBelowThresholdCase() public view {
        // Test case: GPA 3.20 < threshold 3.50
        // Expected: valid = 0, proof still verifies (valid=0 is a valid public signal)
        // Proof values from snarkjs zkey export soliditycalldata

        uint256[2] memory a = [
            uint256(
                0x1f8ef0d7894402ae7bf449662fe9e7feb54ea80c4c77be422866cab931a15d19
            ),
            uint256(
                0x0d7dd8284f0ab32267122b1e2d50bc1deb89d309fab431f1990ce38edb9e0b06
            )
        ];

        uint256[2][2] memory b = [
            [
                uint256(
                    0x0380658e51ea97d62989c7ab983a18c6af03762d4c526a0c1946aaf11505e58a
                ),
                uint256(
                    0x2697c9e9837fdf0befb8a9eb0fca6565ebbc0f98856ca933768bc7d83003cedb
                )
            ],
            [
                uint256(
                    0x1b20f41b755265fe7ebd1bedf437e8b2578b60e747f4fd058aa81ca180969bcf
                ),
                uint256(
                    0x2f14287423802e3b0be5507353a27305670b621a9d840a721dbfa79a26305b59
                )
            ]
        ];

        uint256[2] memory c = [
            uint256(
                0x0752164ed614a76fa149d6916eef81de1d21fe325eb820d95cfe9572378dfb82
            ),
            uint256(
                0x1ef43feae5becb02354ad29719e4296e31e2ac02c20899e619fc1145c4dcd515
            )
        ];

        uint256[1] memory publicSignals = [uint256(0)];

        // Verify the proof - it should still verify because it's cryptographically valid
        bool result = zkolar.verifyCredential(a, b, c, publicSignals);
        assertTrue(
            result,
            "Below threshold case: proof should verify (valid=0 in public signal)"
        );
    }

    function testInvalidProof() public view {
        // Test case: Manipulated proof data
        // Expected: verification fails

        uint256[2] memory a = [
            uint256(
                0x1111111111111111111111111111111111111111111111111111111111111111
            ),
            uint256(
                0x2222222222222222222222222222222222222222222222222222222222222222
            )
        ];

        uint256[2][2] memory b = [
            [
                uint256(
                    0x0000000000000000000000000000000000000000000000000000000000000000
                ),
                uint256(
                    0x0000000000000000000000000000000000000000000000000000000000000000
                )
            ],
            [
                uint256(
                    0x0000000000000000000000000000000000000000000000000000000000000000
                ),
                uint256(
                    0x0000000000000000000000000000000000000000000000000000000000000000
                )
            ]
        ];

        uint256[2] memory c = [
            uint256(
                0x0000000000000000000000000000000000000000000000000000000000000000
            ),
            uint256(
                0x0000000000000000000000000000000000000000000000000000000000000000
            )
        ];

        uint256[1] memory publicSignals = [uint256(1)];

        // Verify the proof - should fail due to manipulated data
        bool result = zkolar.verifyCredential(a, b, c, publicSignals);
        assertFalse(result, "Invalid proof: verification should fail");
    }
}
