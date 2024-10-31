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
import {Sumcheck} from "./sumcheck/Proof.sol";

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
library Verifier {
    function computeFoldsHelped(
        ParsedRound[] memory parsedRounds,
        BN254.ScalarField[][] memory finalRandomnessAnswers,
        MultilinearPoint memory finalFoldingRandomness
    ) public returns (BN254.ScalarField[][] memory) {
        BN254.ScalarField[][] memory result = new BN254.ScalarField[][](parsedRounds.length + 1);
        for (uint256 i = 0; i < parsedRounds.length; i++) {
            BN254.ScalarField[] memory evaluations =
                new BN254.ScalarField[](parsedRounds[i].stirChallengesAnswers.length);
            for (uint256 j = 0; j < parsedRounds[i].stirChallengesAnswers.length; j++) {
                evaluations[j] = Coeffs.evalMultivariate(
                    parsedRounds[i].stirChallengesAnswers[j], parsedRounds[i].foldingRandomness.point
                );
            }
            result[i] = evaluations;
        }

        // final round
        BN254.ScalarField[] memory finalEvaluations = new BN254.ScalarField[](finalRandomnessAnswers.length);
        for (uint256 i = 0; i < finalRandomnessAnswers.length; i++) {
            finalEvaluations[i] = Coeffs.evalMultivariate(finalRandomnessAnswers[i], finalFoldingRandomness.point);
        }
        result[parsedRounds.length] = finalEvaluations;

        return result;
    }

    function parseCommitment(WhirConfig memory config, Arthur memory arthur)
        public
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
        ParsedCommitment memory parsedCommitment,
        Statement memory statement,
        WhirConfig memory config,
        WhirProof memory whirProof
    ) public pure returns (ParsedProof memory) {
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

    function verify(
        WhirConfig memory config,
        Statement memory statement,
        WhirProof memory whirProof,
        Arthur memory arthur
    ) external returns (bool) {
        ParsedCommitment memory parsedCommitment;
        (arthur, parsedCommitment) = parseCommitment(config, arthur);
        ParsedProof memory parsedProof = parseProof(arthur, parsedCommitment, statement, config, whirProof);
        BN254.ScalarField[][] memory computedFolds = computeFoldsHelped(
            parsedProof.rounds, parsedProof.finalRandomnessAnswers, parsedProof.finalFoldingRandomness
        );

        // check first sumcheck
        (SumcheckPolynomial memory prevPoly, BN254.ScalarField randomness) = (
            parsedProof.initialSumcheckRounds[0].polynomial,
            parsedProof.initialSumcheckRounds[0].foldingRandomnessSingle
        );

        BN254.ScalarField expectedSum = Sumcheck.sumOverHyperCube(prevPoly);
        BN254.ScalarField sum = BN254.ScalarField.wrap(0);
        for (uint256 i = 0; i < parsedCommitment.oodAnswers.length; i++) {
            sum = BN254.add(sum, BN254.mul(parsedCommitment.oodAnswers[i], parsedProof.initialCombinationRandomness[i]));
        }
        for (uint256 j = 0; j < statement.evaluations.length; j++) {
            sum = BN254.add(
                sum,
                BN254.mul(
                    statement.evaluations[j],
                    parsedProof.initialCombinationRandomness[parsedCommitment.oodAnswers.length + j]
                )
            );
        }
        Utils.requireEqualScalars(expectedSum, sum);

        // check remaining rounds
        for (uint256 i = 1; i < parsedProof.initialSumcheckRounds.length; i++) {
            (SumcheckPolynomial memory sumcheckPoly, BN254.ScalarField newRandomness) = (
                parsedProof.initialSumcheckRounds[i].polynomial,
                parsedProof.initialSumcheckRounds[i].foldingRandomnessSingle
            );
            expectedSum = Sumcheck.sumOverHyperCube(sumcheckPoly);
            BN254.ScalarField eval =
                Sumcheck.evaluateAtPoint(prevPoly, PolyUtils.newMultilinearPointFromScalar(randomness));
            Utils.requireEqualScalars(expectedSum, eval);

            randomness = newRandomness;
            prevPoly = sumcheckPoly;
        }

        for (uint256 i = 0; i < parsedProof.rounds.length; i++) {
            ParsedRound memory round = parsedProof.rounds[i];
            BN254.ScalarField[] memory folds = computedFolds[i];
            (SumcheckPolynomial memory sumcheckPoly, BN254.ScalarField newRandomness) =
                (round.sumcheckRounds[0].polynomial, round.sumcheckRounds[0].foldingRandomnessSingle);
            BN254.ScalarField claimedSum = BN254.ScalarField.wrap(0);
            BN254.ScalarField eval =
                Sumcheck.evaluateAtPoint(prevPoly, PolyUtils.newMultilinearPointFromScalar(randomness));
            claimedSum = BN254.add(claimedSum, eval);
            BN254.ScalarField valuesSum = BN254.ScalarField.wrap(0);

            for (uint256 j = 0; j < round.oodAnswers.length; j++) {
                valuesSum = BN254.add(valuesSum, BN254.mul(round.oodAnswers[j], round.combinationRandomness[j]));
            }

            for (uint256 j = 0; j < folds.length; j++) {
                valuesSum =
                    BN254.add(valuesSum, BN254.mul(folds[j], round.combinationRandomness[j + round.oodAnswers.length]));
            }

            claimedSum = BN254.add(valuesSum, claimedSum);
            Utils.requireEqualScalars(Sumcheck.sumOverHyperCube(sumcheckPoly), claimedSum);

            prevPoly = sumcheckPoly;
            randomness = newRandomness;

            // check rest of the round
            for (uint256 j = 1; j < round.sumcheckRounds.length; j++) {
                (SumcheckPolynomial memory sumcheckPoly, BN254.ScalarField newRandomness) =
                    (round.sumcheckRounds[j].polynomial, round.sumcheckRounds[j].foldingRandomnessSingle);

                Utils.requireEqualScalars(
                    Sumcheck.sumOverHyperCube(sumcheckPoly),
                    Sumcheck.evaluateAtPoint(prevPoly, PolyUtils.newMultilinearPointFromScalar(randomness))
                );
                prevPoly = sumcheckPoly;
                randomness = newRandomness;
            }
        }

        // check the foldings computed from the proof match evaluations of the polynomial
        BN254.ScalarField[] memory finalFolds = computedFolds[computedFolds.length - 1];
        BN254.ScalarField[] memory finalEvaluations =
            Coeffs.evaluateAtUnivariate(parsedProof.finalCoefficients, parsedProof.finalRandomnessPoints);
        for (uint256 j = 0; j < finalFolds.length; j++) {
            Utils.requireEqualScalars(finalFolds[j], finalEvaluations[j]);
        }

        if (config.finalSumcheckRounds > 0) {
            (SumcheckPolynomial memory sumcheckPoly, BN254.ScalarField newRandomness) = (
                parsedProof.finalSumcheckRounds[0].polynomial,
                parsedProof.finalSumcheckRounds[0].foldingRandomnessSingle
            );

            Utils.requireEqualScalars(
                Sumcheck.sumOverHyperCube(sumcheckPoly),
                Sumcheck.evaluateAtPoint(prevPoly, PolyUtils.newMultilinearPointFromScalar(randomness))
            );

            prevPoly = sumcheckPoly;
            randomness = newRandomness;

            // check remaining rounds
            for (uint256 j = 1; j < parsedProof.finalSumcheckRounds.length; j++) {
                (SumcheckPolynomial memory sumcheckPoly, BN254.ScalarField newRandomness) = (
                    parsedProof.finalSumcheckRounds[j].polynomial,
                    parsedProof.finalSumcheckRounds[j].foldingRandomnessSingle
                );

                Utils.requireEqualScalars(
                    Sumcheck.sumOverHyperCube(sumcheckPoly),
                    Sumcheck.evaluateAtPoint(prevPoly, PolyUtils.newMultilinearPointFromScalar(randomness))
                );

                prevPoly = sumcheckPoly;
                randomness = newRandomness;
            }
        }

        BN254.ScalarField evaluationOfvPoly = computeVPoly(config, parsedProof, parsedCommitment, statement);

        Utils.requireEqualScalars(
            Sumcheck.evaluateAtPoint(prevPoly, PolyUtils.newMultilinearPointFromScalar(randomness)),
            BN254.mul(
                evaluationOfvPoly,
                Coeffs.evalMultivariate(parsedProof.finalCoefficients.coeffs, parsedProof.finalSumcheckRandomness.point)
            )
        );

        return true;
    }

    function computeVPoly(
        WhirConfig memory whirConfig,
        ParsedProof memory parsedProof,
        ParsedCommitment memory parsedCommitment,
        Statement memory statement
    ) public pure returns (BN254.ScalarField) {
        // TODO clean this up. think about how to implement equivalent of rust chain();

        uint256 numVariables = whirConfig.numVariables;

        // compute size required to build the multilinear point
        // The size of the point also requires to know the size of each folding randomness point
        uint256 foldingRandomnessLength =
            parsedProof.finalSumcheckRandomness.point.length + parsedProof.finalFoldingRandomness.point.length;
        for (uint256 i = 0; i < parsedProof.rounds.length; i++) {
            ParsedRound memory round = parsedProof.rounds[i];
            for (uint256 j = 0; j < round.foldingRandomness.point.length; j++) {
                foldingRandomnessLength += 1;
            }
        }

        BN254.ScalarField[] memory foldingRandomnessValues = new BN254.ScalarField[](foldingRandomnessLength);
        uint256 idx;
        for (uint256 i = 0; i < parsedProof.finalSumcheckRandomness.point.length; i++) {
            foldingRandomnessValues[idx] = parsedProof.finalSumcheckRandomness.point[i];
            idx += 1;
        }

        for (uint256 i = 0; i < parsedProof.finalFoldingRandomness.point.length; i++) {
            foldingRandomnessValues[idx] = parsedProof.finalFoldingRandomness.point[i];
            idx += 1;
        }

        for (uint256 i = 0; i < parsedProof.rounds.length; i++) {
            ParsedRound memory round = parsedProof.rounds[parsedProof.rounds.length - 1 - i];
            for (uint256 j = 0; j < round.foldingRandomness.point.length; j++) {
                foldingRandomnessValues[idx] = round.foldingRandomness.point[j];
                idx += 1;
            }
        }

        MultilinearPoint memory foldingRandomness = PolyUtils.newMultilinearPoint(foldingRandomnessValues);

        // compute value
        MultilinearPoint[] memory multilinearPoints =
            new MultilinearPoint[](parsedCommitment.oodPoints.length + statement.points.length);
        for (uint256 i = 0; i < parsedCommitment.oodPoints.length; i++) {
            multilinearPoints[i] = PolyUtils.expandFromUnivariate(parsedCommitment.oodPoints[i], numVariables);
        }

        for (uint256 i = 0; i < statement.points.length; i++) {
            multilinearPoints[parsedCommitment.oodPoints.length + i] = statement.points[i];
        }

        BN254.ScalarField value = BN254.ScalarField.wrap(0);
        for (uint256 i = 0; i < multilinearPoints.length; i++) {
            value = BN254.add(
                value,
                BN254.mul(
                    parsedProof.initialCombinationRandomness[i],
                    PolyUtils.eqPolyOutside(multilinearPoints[i], foldingRandomness)
                )
            );
        }

        // go through round proofs
        for (uint256 i = 0; i < parsedProof.rounds.length; i++) {
            ParsedRound memory roundProof = parsedProof.rounds[i];
            numVariables -= whirConfig.foldingFactor;

            // compute new folding randomness
            BN254.ScalarField[] memory newFoldingRandomnessValues = new BN254.ScalarField[](numVariables);
            for (uint256 j = 0; j < numVariables; j++) {
                newFoldingRandomnessValues[j] = foldingRandomness.point[j];
            }
            foldingRandomness = MultilinearPoint(newFoldingRandomnessValues);

            MultilinearPoint[] memory stirChallenges =
                new MultilinearPoint[](roundProof.oodPoints.length + roundProof.stirChallengePoints.length);
            for (uint256 j = 0; j < roundProof.oodPoints.length; j++) {
                stirChallenges[j] = PolyUtils.expandFromUnivariate(roundProof.oodPoints[j], numVariables);
            }
            for (uint256 j = 0; j < roundProof.stirChallengePoints.length; j++) {
                stirChallenges[j + roundProof.oodPoints.length] =
                    PolyUtils.expandFromUnivariate(roundProof.stirChallengePoints[j], numVariables);
            }

            BN254.ScalarField sumOfClaims = BN254.ScalarField.wrap(0);
            for (uint256 j = 0; j < stirChallenges.length; j++) {
                BN254.ScalarField point = PolyUtils.eqPolyOutside(foldingRandomness, stirChallenges[j]);
                sumOfClaims = BN254.add(sumOfClaims, BN254.mul(point, roundProof.combinationRandomness[j]));
            }

            value = BN254.add(value, sumOfClaims);
        }
        return value;
    }
}
