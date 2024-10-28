// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {MultilinearPoint, PolyUtils} from "./poly_utils/PolyUtils.sol";
import {SumcheckRound} from "./sumcheck/Proof.sol";
import {BN254} from "solidity-bn254/BN254.sol";
import {CoefficientList, Coeffs} from "./poly_utils/Coeffs.sol";
import {Arthur, EVMFs} from "../src/fs/FiatShamir.sol";
import {Utils} from "./utils/Utils.sol";
import {console} from "forge-std/Test.sol";
import {WhirBaseTest} from "../test/WhirBaseTest.t.sol";
import {SumcheckPolynomial, SumcheckRound} from "./sumcheck/Proof.sol";
import {LibSort} from "solady/src/utils/LibSort.sol";
import {MerkleVerifier} from "./merkle/MerkleVerifier.sol";
import {Logging} from "./utils/Logging.sol";

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
    MultilinearPoint finalFoldingRandomness;
    SumcheckRound[] finalSumcheckRounds;
    MultilinearPoint finalSumcheckRandomness;
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
    uint32 finalQueries;
    uint128 finalSumcheckRounds;
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

    function getSumcheckRounds(Arthur memory arthur, uint256 nRounds)
        private
        pure
        returns (Arthur memory, SumcheckRound[] memory, BN254.ScalarField[] memory)
    {
        // initial sumcheck
        BN254.ScalarField[] memory sumcheckPolyEvals;
        BN254.ScalarField[] memory foldingRandomnessSingle;
        BN254.ScalarField[] memory foldingRandomnessPoint = new BN254.ScalarField[](nRounds);

        // sumcheckRounds
        SumcheckRound[] memory sumcheckRounds = new SumcheckRound[](nRounds);
        for (uint256 i = 0; i < nRounds; i++) {
            (arthur, sumcheckPolyEvals) = EVMFs.nextScalars(arthur, 3);
            (arthur, foldingRandomnessSingle) = EVMFs.squeezeScalars(arthur, 1);
            sumcheckRounds[i] = SumcheckRound(SumcheckPolynomial(1, sumcheckPolyEvals), foldingRandomnessSingle[0]);

            // TODO: POW check
            // [..]

            foldingRandomnessPoint[nRounds - 1 - i] = foldingRandomnessSingle[0];
        }
        return (arthur, sumcheckRounds, foldingRandomnessPoint);
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

    function getStirChallengeIndexes(Arthur memory arthur, uint32 numQueries, uint256 domainSize, uint256 foldingFactor)
        private
        pure
        returns (Arthur memory, uint256[] memory)
    {
        BN254.ScalarField[] memory stirGen;
        (arthur, stirGen) = EVMFs.squeezeScalars(arthur, numQueries);
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

    function getOodPointsAndAnswers(Arthur memory arthur, WhirConfig memory config, uint256 round)
        private
        pure
        returns (Arthur memory, BN254.ScalarField[] memory, BN254.ScalarField[] memory)
    {
        BN254.ScalarField[] memory oodPoints = new BN254.ScalarField[](config.roundParameters[round].oodSamples);
        BN254.ScalarField[] memory oodAnswers = new BN254.ScalarField[](config.roundParameters[round].oodSamples);
        if (config.roundParameters[round].oodSamples > 0) {
            (arthur, oodPoints) = EVMFs.squeezeScalars(arthur, config.roundParameters[round].oodSamples);
            (arthur, oodAnswers) = EVMFs.nextScalars(arthur, config.roundParameters[round].oodSamples);
        }
        return (arthur, oodPoints, oodAnswers);
    }

    function verifyMerkleProofRound(WhirProof memory whirProof, bytes32 root, uint256 round)
        private
        pure
        returns (bool)
    {
        return MerkleVerifier.verify(
            whirProof.merkleProofs[round].proof,
            root,
            whirProof.answers[round],
            whirProof.merkleProofs[round].proofFlags
        );
    }

    function getCombinationRandomness(
        Arthur memory arthur,
        uint256[] memory stirChallengeIndexes,
        WhirConfig memory config,
        uint256 round
    ) private pure returns (Arthur memory, BN254.ScalarField[] memory) {
        BN254.ScalarField[] memory combinationRandomnessGen;
        (arthur, combinationRandomnessGen) = EVMFs.squeezeScalars(arthur, 1);
        BN254.ScalarField[] memory combinationRandomness = Utils.expandRandomness(
            combinationRandomnessGen[0], stirChallengeIndexes.length + config.roundParameters[round].oodSamples
        );

        return (arthur, combinationRandomness);
    }

    function parseRounds(
        Arthur memory arthur,
        WhirConfig memory config,
        WhirProof memory whirProof,
        bytes32 curRoot,
        MultilinearPoint memory curFoldingRandomness,
        BN254.ScalarField curDomainGenInv,
        uint256 curDomainSize,
        BN254.ScalarField curExpDomainGen
    )
        private
        pure
        returns (
            Arthur memory,
            ParsedRound[] memory,
            bytes32,
            uint256,
            BN254.ScalarField,
            MultilinearPoint memory,
            BN254.ScalarField
        )
    {
        ParsedRound[] memory parsedRounds = new ParsedRound[](config.roundParameters.length);
        SumcheckRound[] memory sumcheckRounds;
        BN254.ScalarField[] memory foldingRandomnessPoint;

        for (uint256 r = 0; r < config.roundParameters.length; r++) {
            bytes memory newRoot;
            (arthur, newRoot) = EVMFs.nextBytes(arthur, 32);
            BN254.ScalarField[] memory oodPoints;
            BN254.ScalarField[] memory oodAnswers;
            (arthur, oodPoints, oodAnswers) = getOodPointsAndAnswers(arthur, config, r);

            uint256[] memory stirChallengeIndexes;
            (arthur, stirChallengeIndexes) = getStirChallengeIndexes(
                arthur, config.roundParameters[r].numQueries, curDomainSize, config.foldingFactor
            );
            uint256[] memory stirChallengePointsUint = getStirChallengePoints(stirChallengeIndexes, curExpDomainGen);

            // TODO: need to check that the leaf indexes are also correct
            require(verifyMerkleProofRound(whirProof, curRoot, r) == true);

            // TODO: pow check
            // [..]

            BN254.ScalarField[] memory combinationRandomness;
            (arthur, combinationRandomness) = getCombinationRandomness(arthur, stirChallengeIndexes, config, r);

            (arthur, sumcheckRounds, foldingRandomnessPoint) = getSumcheckRounds(arthur, config.foldingFactor);
            MultilinearPoint memory newFoldingRandomness = PolyUtils.newMultilinearPoint(foldingRandomnessPoint);

            BN254.ScalarField[] memory stirChallengePoints = Utils.arrayToScalarField(stirChallengePointsUint);
            BN254.ScalarField[][] memory stirChallengesAnswers = Utils.arrayToScalarField2(whirProof.answers[r]);
            parsedRounds[r] = ParsedRound(
                curFoldingRandomness,
                oodPoints,
                oodAnswers,
                stirChallengeIndexes,
                stirChallengePoints,
                stirChallengesAnswers,
                combinationRandomness,
                sumcheckRounds,
                curDomainGenInv
            );

            curFoldingRandomness = newFoldingRandomness;
            curRoot = Utils.bytesToBytes32(newRoot, 0);
            curDomainGenInv = BN254.mul(curDomainGenInv, curDomainGenInv);
            curDomainSize /= 2;
            curExpDomainGen = BN254.mul(curExpDomainGen, curExpDomainGen);
        }

        return (arthur, parsedRounds, curRoot, curDomainSize, curDomainGenInv, curFoldingRandomness, curExpDomainGen);
    }

    function parseProof(
        Arthur memory arthur,
        ParsedCommitment calldata parsedCommitment,
        Statement calldata statement,
        WhirConfig calldata config,
        WhirProof calldata whirProof
    ) external pure returns (ParsedProof memory) {
        BN254.ScalarField expDomainGen;
        uint256 domainSize;
        BN254.ScalarField domainGenInv;

        bytes32 prevRoot = parsedCommitment.root;
        BN254.ScalarField[] memory initialCombinationRandomness;
        (arthur, initialCombinationRandomness) = getInitialCombinationRandomness(arthur, parsedCommitment, statement);

        // initial sumcheck
        SumcheckRound[] memory sumcheckRounds;
        BN254.ScalarField[] memory foldingRandomnessPoint;
        (arthur, sumcheckRounds, foldingRandomnessPoint) = getSumcheckRounds(arthur, config.foldingFactor);
        MultilinearPoint memory foldingRandomness = PolyUtils.newMultilinearPoint(foldingRandomnessPoint);

        ParsedRound[] memory parsedRounds;
        (arthur, parsedRounds, prevRoot, domainSize, domainGenInv, foldingRandomness, expDomainGen) = parseRounds(
            arthur,
            config,
            whirProof,
            prevRoot,
            foldingRandomness,
            config.domainGenInv,
            config.domainSize,
            config.expDomainGen
        );

        BN254.ScalarField[] memory finalCoefficientsValues;
        (arthur, finalCoefficientsValues) = EVMFs.nextScalars(arthur, uint128(1) << config.finalSumcheckRounds);
        CoefficientList memory finalCoefficients = Coeffs.newCoefficientList(finalCoefficientsValues);

        uint256[] memory finalRandomnessIndexes;
        (arthur, finalRandomnessIndexes) =
            getStirChallengeIndexes(arthur, config.finalQueries, domainSize, config.foldingFactor);

        BN254.ScalarField[] memory finalRandomnessPoints =
            Utils.arrayToScalarField(getStirChallengePoints(finalRandomnessIndexes, expDomainGen));

        BN254.ScalarField[][] memory finalRandomnessAnswers =
            Utils.arrayToScalarField2(whirProof.answers[whirProof.answers.length - 1]);

        // TODO: need to check that the leaf indexes are also correct
        // verify last merkle proof round
        require(verifyMerkleProofRound(whirProof, prevRoot, whirProof.merkleProofs.length - 1) == true);

        // TODO: pow check
        // [..]

        SumcheckRound[] memory finalSumcheckRounds;
        BN254.ScalarField[] memory finalSumcheckRandomnessPoint;
        (arthur, finalSumcheckRounds, finalSumcheckRandomnessPoint) =
            getSumcheckRounds(arthur, config.finalSumcheckRounds);
        MultilinearPoint memory finalSumcheckRandomness = PolyUtils.newMultilinearPoint(finalSumcheckRandomnessPoint);

        ParsedProof memory parsed = ParsedProof(
            initialCombinationRandomness,
            sumcheckRounds,
            parsedRounds,
            domainGenInv,
            finalRandomnessIndexes,
            finalRandomnessPoints,
            finalRandomnessAnswers,
            foldingRandomness,
            finalSumcheckRounds,
            finalSumcheckRandomness,
            finalCoefficients
        );

        return parsed;
    }
}

contract Verifier {
    function verify(Statement memory statement) external pure returns (bool) {}
}
