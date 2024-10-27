// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {BN254} from "solidity-bn254/BN254.sol";
import {console} from "forge-std/Test.sol";
import {WhirBaseTest} from "./WhirBaseTest.t.sol";
import {VerifierUtils, WhirConfig, ParsedCommitment, Statement, WhirProof} from "../src/Verifier.sol";
import {JSONWhirProof, JSONUtils} from "../src/utils/WhirJson.sol";
import {Arthur, EVMFs} from "../src/fs/FiatShamir.sol";
import {MerkleVerifier} from "../src/merkle/MerkleVerifier.sol";

contract VerifierTest is WhirBaseTest {
    function test_verify() external view {
        string memory proofJson = vm.readFile("test/data/proof_6_2_2_ConjectureList_0_ProverHelps.json");
        bytes memory parsed = vm.parseJson(proofJson);
        JSONWhirProof memory jsonProof = abi.decode(parsed, (JSONWhirProof));
        assertEq(jsonProof.statement.evaluations.length, 2);
        assertEq(jsonProof.statement.points.length, 2);
        assertEq(jsonProof.merkleProofs.length, 3);

        WhirConfig memory config = JSONUtils.jsonWhirConfigToWhirConfig(jsonProof.config);
        Statement memory statement = JSONUtils.jsonStatementToStatement(jsonProof.statement);
        WhirProof memory whirProof = JSONUtils.jsonWhirProofToWhirProof(jsonProof);

        assertEq(config.numVariables, 6);
        assertEq(statement.points.length, 2);
        assertEq(statement.points[0].point.length, 6);

        Arthur memory arthur = EVMFs.newArthur();
        arthur.transcript = jsonProof.arthur.transcript;

        ParsedCommitment memory parsedCommitment;
        (arthur, parsedCommitment) = VerifierUtils.parseCommitment(config, arthur);
        VerifierUtils.parseProof(arthur, parsedCommitment, statement, config, whirProof);
    }
}
