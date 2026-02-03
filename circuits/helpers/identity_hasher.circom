pragma circom 2.1.8;

include "circomlib/circuits/poseidon.circom";

template IdentityHasher() {
    signal input gpa;
    signal input salt;
    
    // commitment verification
    component hasher = Poseidon(2);
    hasher.inputs[0] <== gpa;
    hasher.inputs[1] <== salt;
    
    log("Id Hash: ", hasher.out);
}

component main = IdentityHasher();