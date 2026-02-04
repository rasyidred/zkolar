// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "./IVerifier.sol";

contract Zkolar {
    IVerifier public verifier;

    constructor(address _verifier) {
        verifier = IVerifier(_verifier);
    }

    function verifyCredential(
        uint[2] memory a,
        uint[2][2] memory b,
        uint[2] memory c,
        uint[1] memory publicSignal
    ) public view returns (bool) {
        return verifier.verifyProof(a, b, c, publicSignal);
    }
}
