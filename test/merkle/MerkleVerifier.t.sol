// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console, Vm} from "forge-std/Test.sol";
import {MerkleVerifier, MultiProof} from "../../src/merkle/MerkleVerifier.sol";
import {console} from "forge-std/console.sol";

contract MerkleVerifierTest is Test {
    function setUp() public {}

    // @notice tests sample proofs for the tree height of 1 (two leaves)
    function test_verifyMultiProof_1() public view {
        string memory proofJson1 = vm.readFile("test/data/merkle_proof_output_1.json");
        bytes memory parsedProof1 = vm.parseJson(proofJson1);
        MultiProof memory proof1 = abi.decode(parsedProof1, (MultiProof));
        bool res1 = MerkleVerifier.verify(proof1.proof, proof1.root, proof1.leaves, proof1.proofFlags);
        assertEq(res1, true);
    }

    // @notice tests sample proofs for the tree height of 10 (2^10 leaves)
    function test_verifyMultiProof_2_10() public view {
        // Proving a single leaf
        string memory proofJson1 = vm.readFile("test/data/merkle_proof_output_10_1.json");
        bytes memory parsedProof1 = vm.parseJson(proofJson1);
        MultiProof memory proof1 = abi.decode(parsedProof1, (MultiProof));

        bool res1 = MerkleVerifier.verify(proof1.proof, proof1.root, proof1.leaves, proof1.proofFlags);
        assertEq(res1, true);

        // Proving 10 leaves
        string memory proofJson2 = vm.readFile("test/data/merkle_proof_output_10_10.json");
        bytes memory parsedProof2 = vm.parseJson(proofJson2);
        MultiProof memory proof2 = abi.decode(parsedProof2, (MultiProof));

        bool res2 = MerkleVerifier.verify(proof2.proof, proof2.root, proof2.leaves, proof2.proofFlags);
        assertEq(res2, true);

        // Proving 100 leaves
        string memory proofJson3 = vm.readFile("test/data/merkle_proof_output_10_100.json");
        bytes memory parsedProof3 = vm.parseJson(proofJson3);
        MultiProof memory proof3 = abi.decode(parsedProof3, (MultiProof));

        bool res3 = MerkleVerifier.verify(proof3.proof, proof3.root, proof3.leaves, proof3.proofFlags);
        assertEq(res3, true);
    }

    // @notice tests sample proofs for the tree height of 20 (2^20 leaves)
    function test_verifyMultiProof_2_20() public view {
        // Proving a single leaf
        string memory proofJson1 = vm.readFile("test/data/merkle_proof_output_20_1.json");
        bytes memory parsedProof1 = vm.parseJson(proofJson1);
        MultiProof memory proof1 = abi.decode(parsedProof1, (MultiProof));

        bool res1 = MerkleVerifier.verify(proof1.proof, proof1.root, proof1.leaves, proof1.proofFlags);
        assertEq(res1, true);

        // Proving 10 leaves
        string memory proofJson2 = vm.readFile("test/data/merkle_proof_output_20_10.json");
        bytes memory parsedProof2 = vm.parseJson(proofJson2);
        MultiProof memory proof2 = abi.decode(parsedProof2, (MultiProof));

        bool res2 = MerkleVerifier.verify(proof2.proof, proof2.root, proof2.leaves, proof2.proofFlags);
        assertEq(res2, true);

        // Proving 100 leaves
        string memory proofJson3 = vm.readFile("test/data/merkle_proof_output_20_100.json");
        bytes memory parsedProof3 = vm.parseJson(proofJson3);
        MultiProof memory proof3 = abi.decode(parsedProof3, (MultiProof));

        bool res3 = MerkleVerifier.verify(proof3.proof, proof3.root, proof3.leaves, proof3.proofFlags);
        assertEq(res3, true);
    }
}
