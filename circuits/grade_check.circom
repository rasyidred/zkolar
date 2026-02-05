pragma circom 2.1.8;

include "circomlib/circuits/comparators.circom";
include "circomlib/circuits/poseidon.circom";

template GradeCheck() {
    signal input gpa;
    signal input salt;
    signal input threshold;
    signal input identityHash;
    
    signal output valid;
    
    // GPA uses 4.0 scale with 2 decimal precision (e.g., 3.75)
    // Internally represented as fixed-point: actual_value * 100
    // Valid range: 0-400 (represents 0.00-4.00 GPA)
    // Bit width: 9 bits support up to 512 (sufficient for 0-400)
    component greaterThan = GreaterEqThan(9);
    greaterThan.in[0] <== gpa;      // e.g., 375 represents 3.75 GPA
    greaterThan.in[1] <== threshold; // e.g., 350 represents 3.50 threshold
    valid <== greaterThan.out;
    
    // commitment verification
    component hasher = Poseidon(2);
    hasher.inputs[0] <== gpa;
    hasher.inputs[1] <== salt;
    
    hasher.out === identityHash;
}

component main = GradeCheck();