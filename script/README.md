# Deployment Scripts

This directory contains Foundry deployment scripts for the Zkolar smart contracts.

## Prerequisites

1. **Private Key**: Set your deployer private key as an environment variable
2. **RPC URL**: Have an RPC endpoint ready (local Anvil, testnet, or mainnet)
3. **Funded Account**: Ensure the deployer account has sufficient ETH for gas

## Local Deployment (Anvil)

### 1. Start Local Anvil Testnet

```bash
# Terminal 1: Start Anvil
make anvil
# Anvil will run at http://localhost:8545
```

### 2. Deploy Contracts

```bash
# Terminal 2: Deploy using Anvil's default private key
docker compose run --rm dev forge script script/Zkolar.s.sol \
  --rpc-url http://anvil:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast
```

**Anvil Default Account**:
- Address: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`
- Private Key: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`
- Balance: 10,000 ETH

## Testnet Deployment

### Setup Environment Variables

```bash
# .env file (never commit this!)
PRIVATE_KEY=0x...your_private_key
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_API_KEY
ETHERSCAN_API_KEY=YOUR_ETHERSCAN_API_KEY
```

### Deploy to Sepolia

```bash
docker compose run --rm dev forge script script/Zkolar.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

### Deploy to Other Testnets

**Goerli**:
```bash
docker compose run --rm dev forge script script/Zkolar.s.sol \
  --rpc-url https://goerli.infura.io/v3/YOUR_API_KEY \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

**Arbitrum Sepolia**:
```bash
docker compose run --rm dev forge script script/Zkolar.s.sol \
  --rpc-url https://sepolia-rollup.arbitrum.io/rpc \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --verifier-url https://api-sepolia.arbiscan.io/api
```

## Mainnet Deployment

**⚠️ WARNING**: Deploying to mainnet costs real ETH. Test thoroughly on testnets first.

```bash
docker compose run --rm dev forge script script/Zkolar.s.sol \
  --rpc-url $MAINNET_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --slow
```

## Deployed Contracts

The script deploys two contracts:

1. **GradeCheckVerifier** - ZK-SNARK proof verifier (auto-generated from circuit)
2. **Zkolar** - Main application contract that uses the verifier

## Verification

### Verify Deployed Contracts

If verification failed during deployment:

```bash
# Verify GradeCheckVerifier
forge verify-contract \
  --chain-id 11155111 \
  --compiler-version v0.8.33 \
  0xYOUR_VERIFIER_ADDRESS \
  src/GradeCheckVerifier.sol:GradeCheckVerifier \
  --etherscan-api-key $ETHERSCAN_API_KEY

# Verify Zkolar
forge verify-contract \
  --chain-id 11155111 \
  --compiler-version v0.8.33 \
  --constructor-args $(cast abi-encode "constructor(address)" 0xVERIFIER_ADDRESS) \
  0xYOUR_ZKOLAR_ADDRESS \
  src/Zkolar.sol:Zkolar \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

## Interacting with Deployed Contracts

### Using Cast (Foundry CLI)

```bash
# Call verifyCredential on deployed Zkolar contract
cast call 0xZKOLAR_ADDRESS \
  "verifyCredential(uint256[2],uint256[2][2],uint256[2],uint256[1])" \
  "[proof_a_values]" \
  "[[proof_b_values]]" \
  "[proof_c_values]" \
  "[public_signals]" \
  --rpc-url $RPC_URL
```

### Using Web3 Interface

Once verified on Etherscan, you can interact directly via:
- Etherscan: `https://sepolia.etherscan.io/address/0xYOUR_ADDRESS#writeContract`
- Block Explorer Read/Write Contract tabs

## Deployment Artifacts

After deployment, artifacts are stored in:
- `broadcast/Zkolar.s.sol/<chain-id>/run-latest.json` - Latest deployment details
- Contains contract addresses, transaction hashes, and deployment parameters

## Troubleshooting

### "PRIVATE_KEY not found"
```bash
# Set private key environment variable
export PRIVATE_KEY=0x...
```

### "Insufficient funds"
- Ensure deployer account has enough ETH for gas
- Get testnet ETH from faucets:
  - Sepolia: https://sepoliafaucet.com/
  - Goerli: https://goerlifaucet.com/

### "Verification failed"
- Check Etherscan API key is valid
- Try manual verification (see Verification section above)
- Ensure contract source matches deployed bytecode

### "RPC connection failed"
- Verify RPC URL is correct and accessible
- Check if RPC provider is rate-limiting
- Try alternative RPC endpoints

## Security Best Practices

1. **Never commit private keys** - Use environment variables or hardware wallets
2. **Test on testnets first** - Always deploy to testnet before mainnet
3. **Verify contracts** - Always verify source code on block explorers
4. **Audit before mainnet** - Have contracts professionally audited
5. **Use multisig for mainnet** - Consider using Safe (Gnosis Safe) for deployment
6. **Check gas prices** - Use `--slow` flag or set `--gas-price` manually

## Gas Costs (Estimated)

Based on Sepolia testnet deployments:

| Contract | Gas Used | Cost (at 20 gwei) | Cost (at 50 gwei) |
|----------|----------|-------------------|-------------------|
| GradeCheckVerifier | ~900k | ~0.018 ETH | ~0.045 ETH |
| Zkolar | ~200k | ~0.004 ETH | ~0.010 ETH |
| **Total** | **~1.1M** | **~0.022 ETH** | **~0.055 ETH** |

**Note**: Mainnet costs will be higher. Always check current gas prices.

## Resources

- [Foundry Book - Deployment](https://book.getfoundry.sh/forge/deploying)
- [Foundry Scripting Guide](https://book.getfoundry.sh/tutorials/solidity-scripting)
- [Cast Commands](https://book.getfoundry.sh/reference/cast/)
