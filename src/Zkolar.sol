// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "./IGradeCheckVerifier.sol";

contract Zkolar {
    IGradeCheckVerifier public verifier;

    constructor(address _verifier) {
        verifier = IGradeCheckVerifier(_verifier);
    }

    function verifyCredential(
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        uint256[1] memory publicSignal
    ) public view returns (bool) {
        return verifier.verifyProof(a, b, c, publicSignal);
    }
}
