// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {MultilinearPoint} from "./poly_utils/PolyUtils.sol";
import {SumcheckRound} from "./sumcheck/Proof.sol";
import {BN254} from "solidity-bn254/BN254.sol";
import {CoefficientList} from "./poly_utils/Coeffs.sol";
import {Arthur, EVMFs} from "../src/fs/FiatShamir.sol";
import {Utils} from "./utils/Utils.sol";
import {console} from "forge-std/Test.sol";

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

struct Statement {
    MultilinearPoint[] points;
    BN254.ScalarField[] evaluations;
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

struct ParsedCommitment {
    bytes32 root;
    BN254.ScalarField[] oodPoints;
    BN254.ScalarField[] oodAnswers;
}

struct RoundParameters {
    uint256 foldingPowBits;
    uint256 logInvRate;
    uint256 numQueries;
    uint256 oodSamples;
    uint256 powBits;
}

struct WhirConfig {
    uint32 commitmentOodSamples;
    uint256 finalFoldingPowBits;
    uint256 finalLogInvRate;
    uint256 finalPowBits;
    uint256 finalQueries;
    uint256 finalSumcheckRound;
    uint256 foldingFactor;
    uint256 maxPow;
    uint256 numVariables;
    RoundParameters[] roundParameters;
    uint256 securityLevel;
    uint256 startingFoldingPowBits;
    uint256 startingLogInvRate;
}

/// @notice Various utilities used by the whir verifier
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

    /// @notice line 172 in verifier.rs
    function foldedDomainSize(uint256 foldingFactor) external returns (uint256) {}

    function expDomainGen(BN254.ScalarField domainGen, uint256 foldingFactor) external returns (BN254.ScalarField) {}

    function parseCommitment(WhirConfig calldata config, Arthur memory arthur)
        external
        pure
        returns (Arthur memory, ParsedCommitment memory)
    {
        bytes memory root;
        BN254.ScalarField[] memory oodPoints = new BN254.ScalarField[](config.commitmentOodSamples);
        BN254.ScalarField[] memory oodAnswers = new BN254.ScalarField[](config.commitmentOodSamples);
        (arthur, root) = EVMFs.nextBytes(arthur, 32);
        if (config.commitmentOodSamples > 0) {
            (arthur, oodPoints) = EVMFs.squeezeScalars(arthur, config.commitmentOodSamples);
            (arthur, oodAnswers) = EVMFs.nextScalars(arthur, config.commitmentOodSamples);
        }
        return (arthur, ParsedCommitment(Utils.bytesToBytes32(root, 0), oodPoints, oodAnswers));
    }
}

contract Verifier {
    function verify(Statement memory statement) external pure returns (bool) {}
}
