// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {BN254} from "solidity-bn254/BN254.sol";
import {console} from "forge-std/Test.sol";
import {WhirBaseTest} from "./WhirBaseTest.t.sol";
import {VerifierUtils, WhirConfig, ParsedCommitment} from "../src/Verifier.sol";
import {JSONWhirProof, JSONUtils} from "../src/utils/WhirJson.sol";
import {Arthur, EVMFs} from "../src/fs/FiatShamir.sol";

contract VerifierTest is WhirBaseTest {
    function test_verify() external view {
        string memory proofJson = vm.readFile("test/data/proof_6_2_2_ConjectureList_0_ProverHelps.json");
        bytes memory parsed = vm.parseJson(proofJson);
        JSONWhirProof memory jsonProof = abi.decode(parsed, (JSONWhirProof));
        assertEq(jsonProof.statement.evaluations.length, 2);
        assertEq(jsonProof.statement.points.length, 2);
        assertEq(jsonProof.merkleProofs.length, 3);

        WhirConfig memory config = JSONUtils.jsonWhirConfigToWhirConfig(jsonProof.config);
        assertEq(config.numVariables, 6);

        Arthur memory arthur = EVMFs.newArthur();
        arthur.transcript = jsonProof.arthur.transcript;

        ParsedCommitment memory parsedCommitment;
        (arthur, parsedCommitment) = VerifierUtils.parseCommitment(config, arthur);
    }

    // @notice custom test, checked against whir repo
    function test_expandRandomness() external pure {
        BN254.ScalarField base = BN254.ScalarField.wrap(2);
        BN254.ScalarField[] memory res = VerifierUtils.expandRandomness(base, 5);
        assertEqUintScalarField(1, res[0]);
        assertEqUintScalarField(2, res[1]);
        assertEqUintScalarField(4, res[2]);
        assertEqUintScalarField(8, res[3]);
        assertEqUintScalarField(16, res[4]);
    }
}
