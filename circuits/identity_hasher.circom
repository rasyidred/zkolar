pragma circom 2.1.8;

include "circomlib/circuits/poseidon.circom";

template IdentityHasher() {
    signal input gpa;
    signal input salt;
    
    signal output id_hash;
    
    // commitment verification
    component hasher = Poseidon(2);
    hasher.inputs[0] <== gpa;
    hasher.inputs[1] <== salt;
    
    id_hash <== hasher.out;
    log("id_hash:", id_hash);
}

component main = IdentityHasher();