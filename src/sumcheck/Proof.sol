// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {BN254} from "solidity-bn254/BN254.sol";
import {MultilinearPoint} from "../poly_utils/PolyUtils.sol";
import {Utils} from "../utils/Utils.sol";

// @notice polynomials are in F^{<3}[X_1, \dots, X_k]
// it us uniquely determined by it's evaluations over {0, 1, 2}^k
// (notice from whir/sumcheck/proof.rs)
struct SumcheckPolynomial {
    uint256 nVariables;
    BN254.ScalarField[] evaluations;
}

struct SumcheckRound {
    SumcheckPolynomial polynomial;
    uint256 n;
}

library Sumcheck {
    function newSumcheckPoly(BN254.ScalarField[] memory evaluations, uint256 nVariables)
        public
        pure
        returns (SumcheckPolynomial memory)
    {
        return SumcheckPolynomial(nVariables, evaluations);
    }

    function sumOverHyperCube(SumcheckPolynomial memory poly) public pure returns (BN254.ScalarField) {
        uint256 numEvaluationPoints = 3 ** poly.nVariables;
        BN254.ScalarField sum = BN254.ScalarField.wrap(0);
        for (uint256 point = 0; point < numEvaluationPoints; point++) {
            uint8[] memory decomposition = Utils.baseDecomposition(point, 3, poly.nVariables);
            bool allValid = true;
            for (uint256 j = 0; j < poly.nVariables; j++) {
                if (decomposition[j] != 0 && decomposition[j] != 1) {
                    allValid = false;
                    break;
                }
            }
            if (allValid) {
                sum = BN254.add(sum, poly.evaluations[point]);
            }
        }
        return sum;
    }

    function evaluateAtPoint(SumcheckPolynomial memory poly, MultilinearPoint memory point)
        public
        pure
        returns (BN254.ScalarField)
    {}
}
