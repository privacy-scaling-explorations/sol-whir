// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {console} from "forge-std/Test.sol";
import {BN254} from "solidity-bn254/BN254.sol";
import {ParsedRound} from "../WhirStructs.sol";

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

    function logParsedRounds(ParsedRound[] memory rounds) public pure {
        for (uint256 i = 0; i < rounds.length; i++) {
            console.log("[PARSED ROUND] ", i, " [PARSED ROUND]");
            logParsedRound(rounds[i]);
            console.log("+++++++++++++++++++++++++++++++++++++++");
        }
    }

    function logParsedRound(ParsedRound memory round) public pure {
        console.log("Folding randomness ---");
        // logScalars(round.foldingRandomness.point);
        console.log("---");

        console.log("OOD Points ---");
        logScalars(round.oodPoints);
        console.log("---");

        console.log("Challenge Points ---");
        logScalars(round.stirChallengePoints);
        console.log("---");

        console.log("Combination Randomness ---");
        logScalars(round.combinationRandomness);
        console.log("---");
    }
}
