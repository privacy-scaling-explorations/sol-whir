// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console, Vm} from "forge-std/Test.sol";
import {MerkleVerifier} from "src/MerkleVerifier.sol";
import {console} from "forge-std/console.sol";

contract MerkleVerifierTest is Test {
    function setUp() public {}

    function test_verifyMultiProof() public {
        bool[] memory proofFlags = new bool[](6);
        proofFlags[0] = false;
        proofFlags[1] = false;
        proofFlags[2] = false;
        proofFlags[3] = true;
        proofFlags[4] = false;
        proofFlags[5] = true;

        bytes32[] memory proof = new bytes32[](4);
        proof[0] = 0x69c322e3248a5dfc29d73c5b0553b0185a35cd5bb6386747517ef7e53b15e287;
        proof[1] = 0xd33e25809fcaa2b6900567812852539da8559dc8b76a7ce3fc5ddd77e8d19a69;
        proof[2] = 0xf2ee15ea639b73fa3db9b34a245bdfa015c260c598b211bf05a1ecc4b3e3b4f2;
        proof[3] = 0x85d1aff29686ca41ca1ff0ea5cac33eeb9113c8ebdbd49b4140ce981a8540844;

        bytes32[] memory leaves = new bytes32[](3);
        leaves[0] = 0x5fe7f977e71dba2ea1a68e21057beebb9be2ac30c6410aa38d4f3fbe41dcffd2;
        leaves[1] = 0xd0591206d9e81e07f4defc5327957173572bcd1bca7838caa7be39b0c12b1873;
        leaves[2] = 0xf343681465b9efe82c933c3e8748c70cb8aa06539c361de20f72eac04e766393;

        MerkleVerifier verifier = new MerkleVerifier();
        vm.startSnapshotGas("verify");
        bool res = verifier.verify(
            proof, bytes32(0x953bc7822cb1f8081ce76dbec04284edb638d65dbc3d4a8db4332768908aeee4), leaves, proofFlags
        );
        assertEq(res, true);
        uint256 gasUsedAbsorb = vm.stopSnapshotGas("verify");
        assertEq(gasUsedAbsorb, 9948);
    }

    struct ConvertedProof {
        bytes32[] leaves;
        bytes32[] proof;
        bool[] proofFlags;
        bytes32 root;
    }

    function test_verifyMultiProof_file() public {
        string memory proofJson = vm.readFile("./whir-helper/proof_output.json");
        bytes memory parsedProof = vm.parseJson(proofJson);
        ConvertedProof memory proof = abi.decode(parsedProof, (ConvertedProof));

        MerkleVerifier verifier = new MerkleVerifier();
        vm.startSnapshotGas("verify");
        bool res = verifier.verify(proof.proof, proof.root, proof.leaves, proof.proofFlags);
        assertEq(res, true);
        uint256 gasUsedAbsorb = vm.stopSnapshotGas("verify");
        assertEq(gasUsedAbsorb, 10001);
    }
}
