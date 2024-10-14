// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {BN254} from "solidity-bn254/BN254.sol";

import {Sumcheck, SumcheckPolynomial} from "../../src/sumcheck/Proof.sol";
import {Utils} from "../../src/utils/Utils.sol";
import {MultilinearPoint, PolyUtils} from "../../src/poly_utils/PolyUtils.sol";
import {WhirBaseTest} from "../WhirBaseTest.t.sol";

contract ProofTest is WhirBaseTest {
    // @notice test values from whir repo
    function test_evaluation() external pure {
        uint256 numVariables = 2;
        uint256 numEvaluationPoints = 3 ** numVariables;
        BN254.ScalarField[] memory evaluations = new BN254.ScalarField[](numEvaluationPoints);
        for (uint256 i = 0; i < numEvaluationPoints; i++) {
            evaluations[i] = BN254.ScalarField.wrap(i);
        }

        SumcheckPolynomial memory poly = Sumcheck.newSumcheckPoly(evaluations, numVariables);

        for (uint256 i = 0; i < numEvaluationPoints; i++) {
            uint8[] memory decomp = Utils.baseDecomposition(i, 3, numVariables);
            MultilinearPoint memory point = PolyUtils.newMultilinearPoint(Utils.arrayUint8ToScalarField(decomp));
            assertEqScalarField(Sumcheck.evaluateAtPoint(poly, point), poly.evaluations[i]);
        }

        // add a custom check when summing over the hypercube
        // this was crossed check with the whir repo itself
        BN254.ScalarField sum = Sumcheck.sumOverHyperCube(poly);
        assertEqUintScalarField(8, sum);
    }
}
