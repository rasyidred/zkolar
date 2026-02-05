import inquirer from 'inquirer';
import chalk from 'chalk';
import ora from 'ora';
import { buildPoseidon } from 'circomlibjs';
import fs from 'fs/promises';
import { exec } from 'child_process';
import { promisify } from 'util';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const execAsync = promisify(exec);

/**
 * Prompts user for GPA, salt, and threshold inputs
 * @returns {Promise<Object>} Input values with fixed-point conversion
 */
async function promptInputs() {
  console.log(chalk.yellow('📝 Existing test cases for reference:'));
  console.log('  - happy_case: GPA 3.80, salt 12345, threshold 3.50 → PASS (meetsThreshold=1)');
  console.log('  - fail_case: GPA 3.20, salt 67890, threshold 3.50 → FAIL (meetsThreshold=0)\n');

  const answers = await inquirer.prompt([
    {
      type: 'number',
      name: 'gpa',
      message: 'Enter GPA (0.00-4.00):',
      default: 3.75,
      validate: (val) => {
        if (val < 0 || val > 4) return 'GPA must be between 0.00 and 4.00';
        return true;
      }
    },
    {
      type: 'number',
      name: 'salt',
      message: 'Enter salt (random number):',
      default: () => Math.floor(Math.random() * 100000),
      validate: (val) => {
        if (val < 0) return 'Salt must be positive';
        return true;
      }
    },
    {
      type: 'number',
      name: 'threshold',
      message: 'Enter threshold GPA (e.g., 3.50):',
      default: 3.50,
      validate: (val) => {
        if (val < 0 || val > 4) return 'Threshold must be between 0.00 and 4.00';
        return true;
      }
    }
  ]);

  // Convert to fixed-point (multiply by 100)
  return {
    gpa: Math.round(answers.gpa * 100),
    salt: answers.salt.toString(),
    threshold: Math.round(answers.threshold * 100),
    gpaDisplay: answers.gpa.toFixed(2),
    thresholdDisplay: answers.threshold.toFixed(2)
  };
}

/**
 * Generates Poseidon identity hash from GPA and salt
 * @param {Object} inputs - Input values
 * @returns {Promise<string>} Identity hash as string
 */
async function generateIdentityHash(inputs) {
  const spinner = ora('Computing Poseidon identity hash...').start();

  try {
    const poseidon = await buildPoseidon();
    const hash = poseidon([BigInt(inputs.gpa), BigInt(inputs.salt)]);
    const hashStr = poseidon.F.toString(hash);

    spinner.succeed(`Identity Hash: ${chalk.green(hashStr)}`);
    console.log(chalk.dim(`  Computed as: Poseidon(${inputs.gpa}, ${inputs.salt})\n`));

    return hashStr;
  } catch (error) {
    spinner.fail('Failed to generate identity hash');
    throw error;
  }
}

/**
 * Creates test input JSON file for circuit
 * @param {Object} inputs - Input values
 * @param {string} identityHash - Computed identity hash
 */
async function createTestInput(inputs, identityHash) {
  const spinner = ora('Creating test input file...').start();

  try {
    const testInput = {
      gpa: inputs.gpa.toString(),
      salt: inputs.salt,
      threshold: inputs.threshold.toString(),
      identityHash: identityHash
    };

    const filePath = path.join(__dirname, '../circuits/test_inputs/custom_case.json');
    await fs.writeFile(filePath, JSON.stringify(testInput, null, 2));

    spinner.succeed(`Test input saved: ${chalk.cyan('circuits/test_inputs/custom_case.json')}`);
    console.log(chalk.dim(JSON.stringify(testInput, null, 2)) + '\n');
  } catch (error) {
    spinner.fail('Failed to create test input file');
    throw error;
  }
}

/**
 * Generates ZK proof via Docker container
 */
async function generateProof() {
  const spinner = ora('Generating ZK proof (this may take 5-10 seconds)...').start();

  try {
    // Change to project root directory
    const projectRoot = path.join(__dirname, '..');

    // Use Docker Compose to run proof generation
    // Write witness to test_proofs (writable) instead of build (read-only)
    const command = `cd "${projectRoot}" && docker compose run --rm prove bash -c "node circuits/build/grade_check_js/generate_witness.js circuits/build/grade_check_js/grade_check.wasm circuits/test_inputs/custom_case.json circuits/test_proofs/custom_case.wtns && snarkjs groth16 prove circuits/build/grade_check_*_final.zkey circuits/test_proofs/custom_case.wtns circuits/test_proofs/custom_case_proof.json circuits/test_proofs/custom_case_public.json && rm circuits/test_proofs/custom_case.wtns"`;

    await execAsync(command);

    spinner.succeed('ZK proof generated successfully! ✨');
    console.log(chalk.dim('  Output: circuits/test_proofs/custom_case_proof.json\n'));
  } catch (error) {
    spinner.fail('Proof generation failed');
    console.error(chalk.red('Error details:'), error.message);
    throw error;
  }
}

/**
 * Verifies generated proof using snarkjs
 * @returns {Promise<boolean>} Verification result
 */
async function verifyProof() {
  const spinner = ora('Verifying proof with snarkjs...').start();

  try {
    // Change to project root directory
    const projectRoot = path.join(__dirname, '..');

    const command = `cd "${projectRoot}" && docker compose run --rm prove bash -c "snarkjs groth16 verify circuits/build/grade_check_*_verification_key.json circuits/test_proofs/custom_case_public.json circuits/test_proofs/custom_case_proof.json"`;

    const { stdout } = await execAsync(command);
    const verified = stdout.includes('OK!');

    if (verified) {
      spinner.succeed(chalk.green.bold('✅ Proof verified successfully!'));
    } else {
      spinner.fail(chalk.red.bold('❌ Proof verification failed'));
    }

    // Display public signal
    const publicJsonPath = path.join(__dirname, '../circuits/test_proofs/custom_case_public.json');
    const publicJson = await fs.readFile(publicJsonPath, 'utf8');
    const publicSignals = JSON.parse(publicJson);
    const meetsThreshold = publicSignals[0];

    console.log(chalk.cyan(`\n📊 GPA Check Result:`));
    console.log(chalk.cyan(`   meetsThreshold = ${meetsThreshold}`));
    console.log();
    if (meetsThreshold === '1') {
      console.log(chalk.green.bold('   ✅ PASS: GPA meets or exceeds the threshold'));
    } else {
      console.log(chalk.yellow.bold('   ⚠️  FAIL: GPA is below the threshold'));
    }
    console.log();
    console.log(chalk.dim('   Note: The proof is cryptographically valid in both cases.'));
    console.log(chalk.dim('   The proof proves the correctness of the threshold check result.'));

    return verified;
  } catch (error) {
    spinner.fail('Verification failed');
    console.error(chalk.red('Error details:'), error.message);
    throw error;
  }
}

/**
 * Exports Solidity calldata format for easy copy-paste
 */
async function exportSolidityCalldata() {
  console.log(chalk.blue.bold('\n📋 Solidity Calldata Export\n'));

  const { shouldExport } = await inquirer.prompt([
    {
      type: 'confirm',
      name: 'shouldExport',
      message: 'Export Solidity calldata format?',
      default: true
    }
  ]);

  if (!shouldExport) return;

  const spinner = ora('Exporting Solidity calldata...').start();

  try {
    // Change to project root directory
    const projectRoot = path.join(__dirname, '..');

    const command = `cd "${projectRoot}" && docker compose run --rm prove bash -c "snarkjs zkey export soliditycalldata circuits/test_proofs/custom_case_public.json circuits/test_proofs/custom_case_proof.json"`;

    const { stdout } = await execAsync(command);

    spinner.succeed('Solidity calldata generated!');
    console.log(chalk.yellow('\n📄 Copy this into your Solidity test:\n'));
    console.log(chalk.dim('────────────────────────────────────────'));

    // Extract the calldata (last line of output)
    const lines = stdout.trim().split('\n');
    const calldata = lines[lines.length - 1];
    console.log(calldata);

    console.log(chalk.dim('────────────────────────────────────────\n'));

    console.log(chalk.cyan('📝 Example test function:\n'));
    console.log(chalk.dim(`
function testCustomCase() public view {
    // Proof values from playground (custom_case)
    ${calldata}

    bool result = zkolar.verifyCredential(a, b, c, publicSignals);
    assertTrue(result, "Custom case: proof should verify");
}
    `.trim()));
    console.log();
  } catch (error) {
    spinner.fail('Export failed');
    console.error(chalk.red('Error details:'), error.message);
    throw error;
  }
}

/**
 * Main playground flow
 */
async function main() {
  try {
    console.log(chalk.blue.bold('\n🎓 Zkolar Interactive Playground\n'));

    // Step 1: Input stage
    const inputs = await promptInputs();

    // Step 2: Generate identity hash
    const identityHash = await generateIdentityHash(inputs);

    // Step 3: Create test input JSON
    await createTestInput(inputs, identityHash);

    // Step 4: Generate proof via Docker
    await generateProof();

    // Step 5: Verify proof
    const verified = await verifyProof();

    // Step 6: Export Solidity calldata (optional)
    if (verified) {
      await exportSolidityCalldata();
    }

    console.log(chalk.green.bold('\n✨ Playground session complete! ✨\n'));
  } catch (error) {
    console.error(chalk.red.bold('\n❌ Playground failed with error:\n'));
    console.error(error);
    process.exit(1);
  }
}

// Run playground
main();
