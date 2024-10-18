// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console, Vm} from "forge-std/Test.sol";
import {MerkleVerifier} from "src/MerkleVerifier.sol";
import {console} from "forge-std/console.sol";

contract MerkleVerifierTest is Test {
    function setUp() public {}

    struct ConvertedProof {
        bytes32[] leaves;
        bytes32[] proof;
        bool[] proofFlags;
        bytes32 root;
    }

    // @notice tests sample proofs for the tree height of 1 (two leaves)
    function test_verifyMultiProof_1() public {
        MerkleVerifier verifier = new MerkleVerifier();

        string memory proofJson1 = vm.readFile("./whir-helper/proof_output_1.json");
        bytes memory parsedProof1 = vm.parseJson(proofJson1);
        ConvertedProof memory proof1 = abi.decode(parsedProof1, (ConvertedProof));

        vm.startSnapshotGas("verify");
        bool res1 = verifier.verify(proof1.proof, proof1.root, proof1.leaves, proof1.proofFlags);
        assertEq(res1, true);
        uint256 gasUsedAbsorb1 = vm.stopSnapshotGas("verify");
        assertEq(gasUsedAbsorb1, 4841);
    }

    // @notice tests sample proofs for the tree height of 10 (2^10 leaves)
    function test_verifyMultiProof_2_10() public {
        MerkleVerifier verifier = new MerkleVerifier();

        // Proving a single leaf
        string memory proofJson1 = vm.readFile("./whir-helper/proof_output_10_1.json");
        bytes memory parsedProof1 = vm.parseJson(proofJson1);
        ConvertedProof memory proof1 = abi.decode(parsedProof1, (ConvertedProof));

        vm.startSnapshotGas("verify");
        bool res1 = verifier.verify(proof1.proof, proof1.root, proof1.leaves, proof1.proofFlags);
        assertEq(res1, true);
        uint256 gasUsedAbsorb1 = vm.stopSnapshotGas("verify");
        assertEq(gasUsedAbsorb1, 14281);

        // Proving 10 leaves
        string memory proofJson2 = vm.readFile("./whir-helper/proof_output_10_10.json");
        bytes memory parsedProof2 = vm.parseJson(proofJson2);
        ConvertedProof memory proof2 = abi.decode(parsedProof2, (ConvertedProof));

        vm.startSnapshotGas("verify");
        bool res2 = verifier.verify(proof2.proof, proof2.root, proof2.leaves, proof2.proofFlags);
        assertEq(res2, true);
        uint256 gasUsedAbsorb2 = vm.stopSnapshotGas("verify");
        assertEq(gasUsedAbsorb2, 136361);

        // Proving 100 leaves
        string memory proofJson3 = vm.readFile("./whir-helper/proof_output_10_100.json");
        bytes memory parsedProof3 = vm.parseJson(proofJson3);
        ConvertedProof memory proof3 = abi.decode(parsedProof3, (ConvertedProof));

        vm.startSnapshotGas("verify");
        bool res3 = verifier.verify(proof3.proof, proof3.root, proof3.leaves, proof3.proofFlags);
        assertEq(res3, true);
        uint256 gasUsedAbsorb3 = vm.stopSnapshotGas("verify");
        assertEq(gasUsedAbsorb3, 740935);
    }

    // @notice tests sample proofs for the tree height of 20 (2^20 leaves)
    function test_verifyMultiProof_2_20() public {
        MerkleVerifier verifier = new MerkleVerifier();

        // Proving a single leaf
        string memory proofJson1 = vm.readFile("./whir-helper/proof_output_20_1.json");
        bytes memory parsedProof1 = vm.parseJson(proofJson1);
        ConvertedProof memory proof1 = abi.decode(parsedProof1, (ConvertedProof));

        vm.startSnapshotGas("verify");
        bool res1 = verifier.verify(proof1.proof, proof1.root, proof1.leaves, proof1.proofFlags);
        assertEq(res1, true);
        uint256 gasUsedAbsorb1 = vm.stopSnapshotGas("verify");
        assertEq(gasUsedAbsorb1, 24843);

        // Proving 10 leaves
        string memory proofJson2 = vm.readFile("./whir-helper/proof_output_20_10.json");
        bytes memory parsedProof2 = vm.parseJson(proofJson2);
        ConvertedProof memory proof2 = abi.decode(parsedProof2, (ConvertedProof));

        vm.startSnapshotGas("verify");
        bool res2 = verifier.verify(proof2.proof, proof2.root, proof2.leaves, proof2.proofFlags);
        assertEq(res2, true);
        uint256 gasUsedAbsorb2 = vm.stopSnapshotGas("verify");
        assertEq(gasUsedAbsorb2, 306857);

        // Proving 100 leaves
        string memory proofJson3 = vm.readFile("./whir-helper/proof_output_20_100.json");
        bytes memory parsedProof3 = vm.parseJson(proofJson3);
        ConvertedProof memory proof3 = abi.decode(parsedProof3, (ConvertedProof));

        vm.startSnapshotGas("verify");
        bool res3 = verifier.verify(proof3.proof, proof3.root, proof3.leaves, proof3.proofFlags);
        assertEq(res3, true);
        uint256 gasUsedAbsorb3 = vm.stopSnapshotGas("verify");
        assertEq(gasUsedAbsorb3, 3161642);
    }
}
