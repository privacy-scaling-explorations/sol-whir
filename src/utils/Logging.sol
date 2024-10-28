// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {console} from "forge-std/Test.sol";
import {BN254} from "solidity-bn254/BN254.sol";
import {ParsedRound, ParsedProof} from "../Verifier.sol";
import {SumcheckPolynomial} from "../sumcheck/Proof.sol";

library Logging {
    function logScalars(BN254.ScalarField[] memory scalars) public pure {
        for (uint256 i = 0; i < scalars.length; i++) {
            console.log(BN254.ScalarField.unwrap(BN254.add(scalars[i], BN254.ScalarField.wrap(0))));
        }
    }

    function logScalar(BN254.ScalarField scalar) public pure {
        console.log(BN254.ScalarField.unwrap(BN254.add(scalar, BN254.ScalarField.wrap(0))));
    }

    function logUints(uint256[] memory values) public pure {
        for (uint256 i = 0; i < values.length; i++) {
            console.log(values[i]);
        }
    }

    function logSumcheckPolynomial(SumcheckPolynomial memory poly) public pure {
        console.log("Sumcheck Polynomial ---");
        logScalars(poly.evaluations);
        console.log(poly.nVariables);
        console.log("---");
    }

    function logParsedRounds(ParsedRound[] memory rounds) public pure {
        for (uint256 i = 0; i < rounds.length; i++) {
            console.log("[PARSED ROUND] ", i, " [PARSED ROUND]");
            logParsedRound(rounds[i]);
            console.log("+++++++++++++++++++++++++++++++++++++++");
        }
    }

    function logParsedProof(ParsedProof memory parsedProof) public pure {
        console.log("Initial combination randomness: ");
        logScalars(parsedProof.initialCombinationRandomness);
        console.log("---");

        console.log("Initial sumcheck rounds: ");
        for (uint256 i = 0; i < parsedProof.initialSumcheckRounds.length; i++) {
            logSumcheckPolynomial(parsedProof.initialSumcheckRounds[i].polynomial);
        }
        console.log("---");

        logParsedRounds(parsedProof.rounds);

        console.log("Final domain gen inv: ");
        logScalar(parsedProof.finalDomainGenInv);
        console.log("---");

        console.log("Final randomness indexes: ");
        logUints(parsedProof.finalRandomnessIndexes);
        console.log("---");

        console.log("Final randomness points: ");
        logScalars(parsedProof.finalRandomnessPoints);
        console.log("---");

        console.log("Final randomness answers: ");
        for (uint256 j = 0; j < parsedProof.finalRandomnessAnswers.length; j++) {
            console.log("Answers: ");
            logScalars(parsedProof.finalRandomnessAnswers[j]);
            console.log("---");
        }
        console.log("---");

        console.log("Final folding randomness: ");
        logScalars(parsedProof.finalFoldingRandomness.point);
        console.log("---");

        console.log("Final sumcheck rounds: ");
        for (uint256 j = 0; j < parsedProof.finalSumcheckRounds.length; j++) {
            console.log("Sumcheck round: ");
            logScalars(parsedProof.finalRandomnessAnswers[j]);
            console.log("---");
        }
        console.log("---");

        console.log("Final coefficients: ");
        logScalars(parsedProof.finalCoefficients.coeffs);
        //struct ParsedProof {
        //    BN254.ScalarField[] initialCombinationRandomness;
        //    SumcheckRound[] initialSumcheckRounds;
        //    ParsedRound[] rounds;
        //    BN254.ScalarField finalDomainGenInv;
        //    uint256[] finalRandomnessIndexes;
        //    BN254.ScalarField[] finalRandomnessPoints;
        //    BN254.ScalarField[][] finalRandomnessAnswers;
        //    MultilinearPoint finalFoldingRandomness;
        //    SumcheckRound[] finalSumcheckRounds;
        //    MultilinearPoint finalSumcheckRandomness;
        //    CoefficientList finalCoefficients;
        //}
    }

    function logParsedRound(ParsedRound memory round) public pure {
        console.log("Folding randomness ---");
        logScalars(round.foldingRandomness.point);
        console.log("---");

        console.log("OOD Points ---");
        logScalars(round.oodPoints);
        console.log("---");

        console.log("OOD Answers ---");
        logScalars(round.oodAnswers);
        console.log("---");

        console.log("Challenge Indexes ---");
        logUints(round.stirChallengesIndexes);
        console.log("---");

        console.log("Challenge Points ---");
        logScalars(round.stirChallengePoints);
        console.log("---");

        console.log("Challenges Answers ---");
        for (uint256 i = 0; i < round.stirChallengesAnswers.length; i++) {
            console.log("Challenge Answer: ", i);
            logScalars(round.stirChallengesAnswers[i]);
            console.log("---");
        }
        console.log("---");

        console.log("Combination Randomness ---");
        logScalars(round.combinationRandomness);
        console.log("---");

        console.log("SumcheckRounds ---");
        for (uint256 i = 0; i < round.sumcheckRounds.length; i++) {
            console.log("Sumcheck Poly: ", i);
            logSumcheckPolynomial(round.sumcheckRounds[i].polynomial);
            logScalar(round.sumcheckRounds[i].foldingRandomnessSingle);
            console.log("---");
        }

        console.log("Domain Gen Inv ---");
        logScalar(round.domainGenInv);
        console.log("---");
    }
}
