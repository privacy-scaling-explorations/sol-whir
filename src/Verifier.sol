// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {MultilinearPoint} from "./poly_utils/PolyUtils.sol";
import {SumcheckRound} from "./sumcheck/Proof.sol";
import {BN254} from "solidity-bn254/BN254.sol";
import {CoefficientList} from "./poly_utils/Coeffs.sol";

struct ParsedRound {
    MultilinearPoint foldingRandomness;
    BN254.ScalarField[] oodPoints;
    BN254.ScalarField[] oodAnswers;
    uint256[] stirChallengesIndexes;
    BN254.ScalarField[] stirChallengePoints;
    BN254.ScalarField[][] stirChallengesAnswers;
    BN254.ScalarField[] combinationRandomness;
    SumcheckRound[] sumcheckRounds;
    BN254.ScalarField domainGenInv;
}

struct ParsedProof {
    BN254.ScalarField[] initialCombinationRandomness;
    SumcheckRound[] initialSumcheckRounds;
    ParsedRound[] rounds;
    BN254.ScalarField finalDomainGenInv;
    uint256[] finalRandomnessIndexes;
    BN254.ScalarField[] finalRandomnessPoints;
    BN254.ScalarField[][] finalRandomnessAnswers;
    MultilinearPoint[] finalFoldingRandomness;
    SumcheckRound[] finalSumcheckRounds;
    MultilinearPoint[] finalSumcheckRandomness;
    CoefficientList finalCoefficients;
}

library VerifierUtils {
    function computeFoldsHelped(ParsedRound[] memory parsedRounds, BN254.ScalarField[][] memory finalRandomnessAnswers)
        external
    {}

    function expandRandomness(BN254.ScalarField base, uint256 len) external pure returns (BN254.ScalarField[] memory) {
        BN254.ScalarField[] memory res = new BN254.ScalarField[](len);
        BN254.ScalarField acc = BN254.ScalarField.wrap(1);
        for (uint256 i = 0; i < len; i++) {
            res[i] = acc;
            acc = BN254.mul(acc, base);
        }

        return res;
    }
}

contract Verifier {}
