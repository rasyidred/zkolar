pragma circom 2.1.8;

include "circomlib/circuits/comparators.circom";
include "circomlib/circuits/poseidon.circom";

template GradeCheck() {
    signal input gpa;
    signal input salt;
    signal input threshold;
    signal input identityHash;
    
    signal output valid;
    
    // gpa must > = threshold, assuming input are < 2^7 (128)
    component greaterThan = GreaterEqThan(7);
    greaterThan.in[0] <== gpa;
    greaterThan.in[1] <== threshold;
    valid <== greaterThan.out;
    
    // commitment verification
    component hasher = Poseidon(2);
    hasher.inputs[0] <== gpa;
    hasher.inputs[1] <== salt;
    
    hasher.out === identityHash;
}

component main = GradeCheck();