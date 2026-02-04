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
        assertEq(address(zkolar.verifier()), address(verifier), "Verifier address should match");
    }

    function testHappyCase() public view {
        // Test case: GPA 3.80 >= threshold 3.50
        // Expected: valid = 1, verification succeeds

        uint[2] memory a = [
            uint(82406501638694137882453771813268438205495940990441489104518106709362982920),
            uint(7991155212724172728674141841035846694989504627449545245736655863814007852846)
        ];

        uint[2][2] memory b = [
            [uint(19734396770615492267078223410845074538766259976278178968092843485533711779585),
             uint(4258269764559210706802061121920069382096500378719548948325155460142068127740)],
            [uint(16397019722035261304483971446921277693844064241193550372375953771700497356488),
             uint(7660217032398716754412168020524857661474287465689963696709565996091892696724)]
        ];

        uint[2] memory c = [
            uint(15739187030190819159973315174403398914779180233501491520932616473986564966603),
            uint(1041041671674480930527868242329543615004744383198989288345941235746672786435)
        ];

        uint[1] memory publicSignals = [uint(1)];

        // Verify the proof
        bool result = zkolar.verifyCredential(a, b, c, publicSignals);
        assertTrue(result, "Happy case: proof should verify successfully");
    }

    function testBelowThresholdCase() public view {
        // Test case: GPA 3.20 < threshold 3.50
        // Expected: valid = 0, but proof still verifies

        uint[2] memory a = [
            uint(1969907656354063352177777761405467388205350094223289548599065914726847520379),
            uint(1221415186124045344144233014098660180044175412070702857330033692425790465666)
        ];

        uint[2][2] memory b = [
            [uint(3590875795859521649186640285438004531598557579567642934830477329000251150675),
             uint(18845888605754545759293820933898368143578676393273038076905137260271452592695)],
            [uint(9213904272643160047548156515881245037932030542543201253756575060863754902345),
             uint(3259798010379484500662580647448723249704777306696813539904110268383673280110)]
        ];

        uint[2] memory c = [
            uint(8575226746250824571947696202426044107533253671640688850304157388484968869029),
            uint(20420825098842367479090614324903442345848588074010298541208571985758967752702)
        ];

        uint[1] memory publicSignals = [uint(0)];

        // Verify the proof - it should still verify because it's cryptographically valid
        bool result = zkolar.verifyCredential(a, b, c, publicSignals);
        assertTrue(result, "Below threshold case: proof should verify (but valid=0 in public signal)");
    }

    function testInvalidProof() public view {
        // Test case: Manipulated proof data
        // Expected: verification fails

        uint[2] memory a = [
            uint(0x1111111111111111111111111111111111111111111111111111111111111111),
            uint(0x2222222222222222222222222222222222222222222222222222222222222222)
        ];

        uint[2][2] memory b = [
            [uint(0x0000000000000000000000000000000000000000000000000000000000000000),
             uint(0x0000000000000000000000000000000000000000000000000000000000000000)],
            [uint(0x0000000000000000000000000000000000000000000000000000000000000000),
             uint(0x0000000000000000000000000000000000000000000000000000000000000000)]
        ];

        uint[2] memory c = [
            uint(0x0000000000000000000000000000000000000000000000000000000000000000),
            uint(0x0000000000000000000000000000000000000000000000000000000000000000)
        ];

        uint[1] memory publicSignals = [uint(1)];

        // Verify the proof - should fail due to manipulated data
        bool result = zkolar.verifyCredential(a, b, c, publicSignals);
        assertFalse(result, "Invalid proof: verification should fail");
    }
}
