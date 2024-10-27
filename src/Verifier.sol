// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {MultilinearPoint, PolyUtils} from "./poly_utils/PolyUtils.sol";
import {SumcheckRound} from "./sumcheck/Proof.sol";
import {BN254} from "solidity-bn254/BN254.sol";
import {CoefficientList} from "./poly_utils/Coeffs.sol";
import {Arthur, EVMFs} from "../src/fs/FiatShamir.sol";
import {Utils} from "./utils/Utils.sol";
import {console} from "forge-std/Test.sol";
import {WhirBaseTest} from "../test/WhirBaseTest.t.sol";
import {SumcheckPolynomial, SumcheckRound} from "./sumcheck/Proof.sol";
import {LibSort} from "solady/src/utils/LibSort.sol";
import {MerkleVerifier} from "./merkle/MerkleVerifier.sol";

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
    uint32 numQueries;
    uint32 oodSamples;
    uint256 powBits;
}

struct MerkleProof {
    bytes32[] proof;
    bool[] proofFlags;
}

struct WhirProof {
    uint256[][][] answers;
    MerkleProof[] merkleProofs;
}

struct WhirConfig {
    uint32 commitmentOodSamples;
    BN254.ScalarField domainGen;
    BN254.ScalarField domainGenInv;
    uint256 domainSize;
    BN254.ScalarField expDomainGen;
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

    /// @notice line 172 in verifier.rs
    function foldedDomainSize(uint256 foldingFactor) external returns (uint256) {}

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

    function getSumcheckRounds(Arthur memory arthur, WhirConfig memory config)
        private
        pure
        returns (Arthur memory, SumcheckRound[] memory, MultilinearPoint memory)
    {
        // initial sumcheck
        BN254.ScalarField[] memory sumcheckPolyEvals;
        BN254.ScalarField[] memory foldingRandomnessSingle;
        BN254.ScalarField[] memory foldingRandomnessPoint = new BN254.ScalarField[](config.foldingFactor);

        // sumcheckRounds
        SumcheckRound[] memory sumcheckRounds = new SumcheckRound[](config.foldingFactor);
        for (uint256 i = 0; i < config.foldingFactor; i++) {
            (arthur, sumcheckPolyEvals) = EVMFs.nextScalars(arthur, 3);
            (arthur, foldingRandomnessSingle) = EVMFs.squeezeScalars(arthur, 1);
            sumcheckRounds[i] = SumcheckRound(SumcheckPolynomial(1, sumcheckPolyEvals), foldingRandomnessSingle[0]);
            // TODO: POW check
            foldingRandomnessPoint[config.foldingFactor - 1 - i] = foldingRandomnessSingle[0];
        }
        MultilinearPoint memory foldingRandomness = PolyUtils.newMultilinearPoint(foldingRandomnessPoint);
        return (arthur, sumcheckRounds, foldingRandomness);
    }

    function getInitialCombinationRandomness(
        Arthur memory arthur,
        ParsedCommitment memory parsedCommitment,
        Statement memory statement
    ) private pure returns (Arthur memory, BN254.ScalarField[] memory) {
        BN254.ScalarField[] memory combinationRandomnessGen;
        (arthur, combinationRandomnessGen) = EVMFs.squeezeScalars(arthur, 1);
        return (
            arthur,
            Utils.expandRandomness(
                combinationRandomnessGen[0], parsedCommitment.oodPoints.length + statement.points.length
            )
        );
    }

    function getStirChallengeIndexes(
        Arthur memory arthur,
        RoundParameters memory roundParameters,
        uint256 domainSize,
        uint256 foldingFactor
    ) private pure returns (Arthur memory, uint256[] memory) {
        BN254.ScalarField[] memory stirGen;
        (arthur, stirGen) = EVMFs.squeezeScalars(arthur, roundParameters.numQueries);
        uint256[] memory stirChallengeIndexes = Utils.rangedArray(stirGen, domainSize / (1 << foldingFactor));
        LibSort.sort(stirChallengeIndexes);
        LibSort.uniquifySorted(stirChallengeIndexes);
        return (arthur, stirChallengeIndexes);
    }

    function getStirChallengePoints(uint256[] memory stirChallengeIndexes, BN254.ScalarField expDomainGen)
        private
        pure
        returns (uint256[] memory)
    {
        uint256[] memory stirChallengePoints = new uint256[](stirChallengeIndexes.length);
        for (uint256 i = 0; i < stirChallengeIndexes.length; i++) {
            stirChallengePoints[i] =
                BN254.powSmall(BN254.ScalarField.unwrap(expDomainGen), stirChallengeIndexes[i], BN254.R_MOD);
        }
        return stirChallengePoints;
    }

    function parseProof(
        Arthur memory arthur,
        ParsedCommitment calldata parsedCommitment,
        Statement calldata statement,
        WhirConfig calldata config,
        WhirProof calldata whirProof
    ) external pure {
        bytes32 prevRoot = parsedCommitment.root;
        BN254.ScalarField[] memory initialCombinationRandomness;
        (arthur, initialCombinationRandomness) = getInitialCombinationRandomness(arthur, parsedCommitment, statement);

        // initial sumcheck
        SumcheckRound[] memory sumcheckRounds;
        MultilinearPoint memory foldingRandomness;
        (arthur, sumcheckRounds, foldingRandomness) = getSumcheckRounds(arthur, config);

        for (uint256 r = 0; r < config.roundParameters.length; r++) {
            bytes memory newRoot;
            (arthur, newRoot) = EVMFs.nextBytes(arthur, 32);
            BN254.ScalarField[] memory oodPoints = new BN254.ScalarField[](config.roundParameters[r].oodSamples);
            BN254.ScalarField[] memory oodAnswers = new BN254.ScalarField[](config.roundParameters[r].oodSamples);
            if (config.roundParameters[r].oodSamples > 0) {
                (arthur, oodPoints) = EVMFs.squeezeScalars(arthur, config.roundParameters[r].oodSamples);
                (arthur, oodAnswers) = EVMFs.nextScalars(arthur, config.roundParameters[r].oodSamples);
            }

            //uint256[] memory stirChallengeIndexes;
            //(arthur, stirChallengeIndexes) =
            //    getStirChallengeIndexes(arthur, config.roundParameters[r], config.domainSize, config.foldingFactor);
            //uint256[] memory stirChallengePoints = getStirChallengePoints(stirChallengeIndexes, config.expDomainGen);
        }
    }
}

contract Verifier {
    function verify(Statement memory statement) external pure returns (bool) {}
}
