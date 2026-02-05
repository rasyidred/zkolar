// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "forge-std/Script.sol";
import "../src/GradeCheckVerifier.sol";
import "../src/Zkolar.sol";

/**
 * @title Zkolar Deployment Script
 * @notice Deploys the GradeCheckVerifier and Zkolar contracts
 * @dev Usage:
 *   Local:  forge script script/Zkolar.s.sol --rpc-url http://localhost:8545 --broadcast
 *   Testnet: forge script script/Zkolar.s.sol --rpc-url $RPC_URL --broadcast --verify
 */
contract ZkolarScript is Script {
    function run() external {
        // Read private key from environment variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy GradeCheckVerifier
        console.log("Deploying GradeCheckVerifier...");
        GradeCheckVerifier verifier = new GradeCheckVerifier();
        console.log("GradeCheckVerifier deployed at:", address(verifier));

        // Deploy Zkolar contract with verifier address
        console.log("Deploying Zkolar...");
        Zkolar zkolar = new Zkolar(address(verifier));
        console.log("Zkolar deployed at:", address(zkolar));

        vm.stopBroadcast();

        // Log deployment summary
        console.log("\n=== Deployment Summary ===");
        console.log("GradeCheckVerifier:", address(verifier));
        console.log("Zkolar:", address(zkolar));
        console.log("=========================\n");
    }
}
