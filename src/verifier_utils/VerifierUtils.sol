// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {BN254} from "solidity-bn254/BN254.sol";
import {Multivariate} from "../poly_utils/Coeffs.sol";
import {EVMFs} from "../fs/FiatShamir.sol";
import {Sumcheck, SumcheckRound} from "../sumcheck/Proof.sol";
import {Utils} from "../utils/Utils.sol";
import {MerkleVerifier} from "../merkle/MerkleVerifier.sol";
import {StirUtils} from "../utils/Stir.sol";
import {LibSort} from "solady/src/utils/LibSort.sol";
import {WhirConfig, Statement, WhirProof, ParsedRound, RoundParameters} from "../WhirStructs.sol";
import {Univariate} from "../poly_utils/Coeffs.sol";

library VerifierUtils {
    uint256 internal constant R_MOD = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    uint256 internal constant BN254_MINUS_ONE =
        21888242871839275222246405745257275088548364400416034343698204186575808495616;
    uint256 internal constant BN254_MINUS_TWO =
        21888242871839275222246405745257275088548364400416034343698204186575808495615;
    uint256 internal constant BN254_TWO_INV =
        10944121435919637611123202872628637544274182200208017171849102093287904247809;

    function parseCommitment(uint32 commitmentOodSamples, bytes calldata transcript, uint256 cur)
        internal
        pure
        returns (uint256, bytes32, bytes32, BN254.ScalarField[] memory, BN254.ScalarField[] memory)
    {
        bytes32 state;
        bytes32 root;

        BN254.ScalarField[] memory oodPoints = new BN254.ScalarField[](commitmentOodSamples);
        BN254.ScalarField[] memory oodAnswers = new BN254.ScalarField[](commitmentOodSamples);
        (cur, state, root) = EVMFs.nextBytes32(transcript, cur);
        if (commitmentOodSamples > 0) {
            (oodPoints) = EVMFs.squeezeScalars(state, commitmentOodSamples);
            (cur, state, oodAnswers) = EVMFs.nextScalars(transcript, cur, commitmentOodSamples);
        }
        return (cur, state, root, oodPoints, oodAnswers);
    }

    function parseRounds(
        bytes calldata transcript,
        uint256 cur,
        bytes32 state,
        WhirConfig calldata config,
        uint256 statementPointsLength,
        BN254.ScalarField[] calldata statementEvaluations,
        WhirProof calldata whirProof,
        uint256 curDomainSize,
        BN254.ScalarField curExpDomainGen
    )
        external
        pure
        returns (
            uint256,
            bytes32,
            ParsedRound[] memory,
            bytes32,
            uint256,
            BN254.ScalarField[] memory,
            BN254.ScalarField,
            BN254.ScalarField,
            BN254.ScalarField,
            BN254.ScalarField,
            BN254.ScalarField[] memory,
            BN254.ScalarField[] memory,
            BN254.ScalarField
        )
    {
        BN254.ScalarField curDomainGenInv = config.domainGenInv;
        bytes32 curRoot;
        BN254.ScalarField[] memory parsedCommitmentOodPoints;
        BN254.ScalarField[] memory parsedCommitmentOodAnswers;
        (cur, state, curRoot, parsedCommitmentOodPoints, parsedCommitmentOodAnswers) =
            parseCommitment(config.commitmentOodSamples, transcript, cur);

        BN254.ScalarField combinationRandomnessGen = EVMFs.squeezeScalars1(state);

        BN254.ScalarField[] memory initialCombinationRandomness =
            Utils.expandRandomness(combinationRandomnessGen, parsedCommitmentOodPoints.length + statementPointsLength);

        // initial sumcheck
        BN254.ScalarField[] memory foldingRandomnessPoint = new BN254.ScalarField[](config.foldingFactor);
        BN254.ScalarField claimedSum;

        // compute the initial claimed sum
        assembly ("memory-safe") {
            // compute sum from the ood answers of the commitment
            // comment it out for now, since we need to handle the calldata from above sum := 0
            let nAnswers := mload(parsedCommitmentOodAnswers)
            let oodAnswers := add(parsedCommitmentOodAnswers, 0x20)
            let combRand := add(initialCombinationRandomness, 0x20)

            // start to accumulate the sum, going over the ood answers and the combination randomness
            for { let i := 0 } lt(i, nAnswers) { i := add(i, 1) } {
                let answer := mload(add(oodAnswers, mul(0x20, i)))
                let rand := mload(add(combRand, mul(0x20, i)))
                claimedSum := addmod(claimedSum, mulmod(answer, rand, R_MOD), R_MOD)
            }

            // statements evaluations are contained in calldata, accumulate sum accordingly
            // we will also need to access the combination randomness starting at length(oodAnswers)
            let nEvals := statementEvaluations.length
            let evals := statementEvaluations.offset
            combRand := add(combRand, mul(nAnswers, 0x20)) // update the comb rand pointer
            for { let i := 0 } lt(i, nEvals) { i := add(i, 1) } {
                let rand := mload(add(combRand, mul(i, 0x20)))
                let eval := calldataload(add(evals, mul(i, 0x20)))
                claimedSum := addmod(claimedSum, mulmod(rand, eval, R_MOD), R_MOD)
            }
        }

        BN254.ScalarField e0;
        BN254.ScalarField e1;
        BN254.ScalarField e2;
        (cur, state, foldingRandomnessPoint, e0, e1, e2) = Sumcheck.getSumcheckRounds_1(
            transcript, cur, state, config.startingFoldingPowBits, claimedSum, config.foldingFactor
        );

        // initialize variables outside the assembly statement, we will re-use them below, in another asm block
        BN254.ScalarField randomness = foldingRandomnessPoint[0];

        ParsedRound[] memory parsedRounds = new ParsedRound[](config.roundParameters.length);
        BN254.ScalarField[] memory combinationRandomness;
        uint256[] memory stirChallengeIndexes;

        for (uint256 r = 0; r < config.roundParameters.length; r++) {
            bytes32 newRoot;
            RoundParameters memory roundParameters = config.roundParameters[r];
            (cur, state, newRoot) = EVMFs.nextBytes32(transcript, cur);
            uint128 nOodSamples = roundParameters.oodSamples;
            BN254.ScalarField[] memory oodPoints = new BN254.ScalarField[](nOodSamples);
            BN254.ScalarField[] memory oodAnswers = new BN254.ScalarField[](nOodSamples);

            if (nOodSamples > 0) {
                if (nOodSamples == 1) {
                    oodPoints[0] = EVMFs.squeezeScalars1(state);
                    (cur, state, oodAnswers) = EVMFs.nextScalars1(transcript, cur);
                } else {
                    (oodPoints) = EVMFs.squeezeScalars(state, roundParameters.oodSamples);
                    (cur, state, oodAnswers) = EVMFs.nextScalars(transcript, cur, roundParameters.oodSamples);
                }
            }

            // get the challenge indexes, which we sort and uniquify
            // we use them to then check that merkle proof is correct
            stirChallengeIndexes =
                EVMFs.squeezeRangedUints(state, roundParameters.numQueries, curDomainSize / (1 << config.foldingFactor));
            LibSort.sort(stirChallengeIndexes);
            LibSort.uniquifySorted(stirChallengeIndexes);

            MerkleVerifier.verify(
                curRoot,
                whirProof.merkleProofs[r].depth,
                stirChallengeIndexes,
                whirProof.answers[r],
                whirProof.merkleProofs[r].decommitments
            );

            // pow check
            if (roundParameters.powBits > 0) {
                (cur, state) = EVMFs.checkPow(transcript, cur, state, roundParameters.powBits);
            }

            // start to compute claimed sum for upcoming sumcheck
            // we need first to do an evaluation and get the "generator" for the randomness vector that we will compute
            claimedSum = Sumcheck.evaluateAtPoint1_3(e0, e1, e2, randomness);

            combinationRandomnessGen = EVMFs.squeezeScalars1(state);
            combinationRandomness = Utils.expandRandomness(
                combinationRandomnessGen, stirChallengeIndexes.length + roundParameters.oodSamples
            );

            // some assembly to start computing the claimed sum,
            BN254.ScalarField valuesSum;
            assembly ("memory-safe") {
                let n := mload(oodAnswers)
                for { let j := 0 } lt(j, n) { j := add(j, 1) } {
                    let offset := mul(0x20, add(j, 1))
                    let oodAns := mload(add(oodAnswers, offset))
                    let rand := mload(add(combinationRandomness, offset))
                    valuesSum := addmod(valuesSum, mulmod(oodAns, rand, R_MOD), R_MOD)
                }
            }

            // order matters regarding the below initialization!
            // it should come before assigning the new foldingRandomnessPoint below, coming from next sumcheck
            // we need to initialize parsedRounds here, because we initialize the new foldingRandomnessPoint below
            // this allows use to avoid allocating memory twice, for the current point and the upcoming one
            parsedRounds[r] = ParsedRound(
                foldingRandomnessPoint,
                oodPoints,
                StirUtils.getStirChallengePoints(stirChallengeIndexes, curExpDomainGen),
                combinationRandomness
            );

            // get address of the folding randomness point.
            // we pass this ptr it to the multivariate evaluation fn below
            uint256 pointPtr;
            assembly {
                pointPtr := foldingRandomnessPoint
            }

            // continue to compute claimed sum by computing folds for rounds
            for (uint256 j = 0; j < whirProof.answers[r].length; j++) {
                // pass a ptr to the point instead of the point itself, when performing the multivariate eval
                BN254.ScalarField evaluation = evalMultivariateBytes32(whirProof.answers[r][j], pointPtr);
                valuesSum = BN254.add(valuesSum, BN254.mul(evaluation, combinationRandomness[j + oodAnswers.length]));
            }
            claimedSum = BN254.add(valuesSum, claimedSum);

            // now that the parsed round has been assigned, we can assign the new foldingRandomnessPoint
            // go over each of the rounds, assign the randomness
            (cur, state, foldingRandomnessPoint, e0, e1, e2) = Sumcheck.getSumcheckRounds_1(
                transcript, cur, state, roundParameters.foldingPowBits, claimedSum, config.foldingFactor
            );
            randomness = foldingRandomnessPoint[0];

            curRoot = newRoot;
            curDomainGenInv = BN254.mul(curDomainGenInv, curDomainGenInv);
            curDomainSize /= 2;
            curExpDomainGen = BN254.mul(curExpDomainGen, curExpDomainGen);
        }

        return (
            cur,
            state,
            parsedRounds,
            curRoot,
            curDomainSize,
            foldingRandomnessPoint,
            curExpDomainGen,
            e0,
            e1,
            e2,
            parsedCommitmentOodPoints,
            initialCombinationRandomness,
            randomness
        );
    }

    // @dev Follows the implementation from https://github.com/WizardOfMenlo/whir/blob/cb3de2c886804b0cac022738479b931916bd57c1/src/poly_utils/coeffs.rs#L123
    // `ptrToPoint` is a pointer to the poinrt being evaluated (the folding randomness)
    // TODO: removed the recursive step for now, only considering len(point) \in [1, .. , 4]
    function evalMultivariateBytes32(bytes32[] calldata coeffs, uint256 ptrToPoint)
        internal
        pure
        returns (BN254.ScalarField res)
    {
        uint256 len;
        assembly ("memory-safe") {
            let pointLen := mload(ptrToPoint)
            len := pointLen
            let pointPtr := add(ptrToPoint, 0x20)
            switch pointLen
            case 0 { res := calldataload(coeffs.offset) }
            case 1 {
                let c0 := calldataload(coeffs.offset)
                let c1 := calldataload(add(coeffs.offset, 0x20))
                let p0 := mload(pointPtr)
                res := addmod(c0, mulmod(c1, p0, R_MOD), R_MOD)
            }
            case 2 {
                let c0 := calldataload(coeffs.offset)
                let c1 := calldataload(add(coeffs.offset, 0x20))
                let c2 := calldataload(add(coeffs.offset, 0x40))
                let c3 := calldataload(add(coeffs.offset, 0x60))
                let p0 := mload(pointPtr)
                let p1 := mload(add(pointPtr, 0x20))
                let b0 := addmod(c0, mulmod(c1, p1, R_MOD), R_MOD)
                let b1 := addmod(c2, mulmod(c3, p1, R_MOD), R_MOD)
                res := addmod(b0, mulmod(b1, p0, R_MOD), R_MOD)
            }
            case 3 {
                let c0 := calldataload(coeffs.offset)
                let c1 := calldataload(add(coeffs.offset, 0x20))
                let c2 := calldataload(add(coeffs.offset, 0x40))
                let c3 := calldataload(add(coeffs.offset, 0x60))
                let c4 := calldataload(add(coeffs.offset, 0x80))
                let c5 := calldataload(add(coeffs.offset, 0xa0))
                let c6 := calldataload(add(coeffs.offset, 0xc0))
                let c7 := calldataload(add(coeffs.offset, 0xe0))
                let p0 := mload(pointPtr)
                let p1 := mload(add(pointPtr, 0x20))
                let p2 := mload(add(pointPtr, 0x40))
                let b00 := addmod(c0, mulmod(c1, p2, R_MOD), R_MOD)
                let b01 := addmod(c2, mulmod(c3, p2, R_MOD), R_MOD)
                let b10 := addmod(c4, mulmod(c5, p2, R_MOD), R_MOD)
                let b11 := addmod(c6, mulmod(c7, p2, R_MOD), R_MOD)
                let b0 := addmod(b00, mulmod(b01, p1, R_MOD), R_MOD)
                let b1 := addmod(b10, mulmod(b11, p1, R_MOD), R_MOD)
                res := addmod(b0, mulmod(b1, p0, R_MOD), R_MOD)
            }
            case 4 {
                let c0 := calldataload(coeffs.offset)
                let c1 := calldataload(add(coeffs.offset, 0x20))
                let c2 := calldataload(add(coeffs.offset, 0x40))
                let c3 := calldataload(add(coeffs.offset, 0x60))
                let c4 := calldataload(add(coeffs.offset, 0x80))
                let c5 := calldataload(add(coeffs.offset, 0xa0))
                let c6 := calldataload(add(coeffs.offset, 0xc0))
                let c7 := calldataload(add(coeffs.offset, 0xe0))
                let c8 := calldataload(add(coeffs.offset, 0x100))
                let c9 := calldataload(add(coeffs.offset, 0x120))
                let c10 := calldataload(add(coeffs.offset, 0x140))
                let c11 := calldataload(add(coeffs.offset, 0x160))
                let c12 := calldataload(add(coeffs.offset, 0x180))
                let c13 := calldataload(add(coeffs.offset, 0x1a0))
                let c14 := calldataload(add(coeffs.offset, 0x1c0))
                let c15 := calldataload(add(coeffs.offset, 0x1e0))
                let p0 := mload(pointPtr)
                let p1 := mload(add(pointPtr, 0x20))
                let p2 := mload(add(pointPtr, 0x40))
                let p3 := mload(add(pointPtr, 0x60))

                let b00 :=
                    addmod(
                        addmod(c0, mulmod(c1, p3, R_MOD), R_MOD),
                        mulmod(addmod(c2, mulmod(c3, p3, R_MOD), R_MOD), p2, R_MOD),
                        R_MOD
                    )

                let b01 :=
                    addmod(
                        addmod(c4, mulmod(c5, p3, R_MOD), R_MOD),
                        mulmod(addmod(c6, mulmod(c7, p3, R_MOD), R_MOD), p2, R_MOD),
                        R_MOD
                    )

                let b10 :=
                    addmod(
                        addmod(c8, mulmod(c9, p3, R_MOD), R_MOD),
                        mulmod(addmod(c10, mulmod(c11, p3, R_MOD), R_MOD), p2, R_MOD),
                        R_MOD
                    )

                let b11 :=
                    addmod(
                        addmod(c12, mulmod(c13, p3, R_MOD), R_MOD),
                        mulmod(addmod(c14, mulmod(c15, p3, R_MOD), R_MOD), p2, R_MOD),
                        R_MOD
                    )

                let b0 := addmod(b00, mulmod(b01, p1, R_MOD), R_MOD)
                let b1 := addmod(b10, mulmod(b11, p1, R_MOD), R_MOD)
                res := addmod(b0, mulmod(b1, p0, R_MOD), R_MOD)
            }
            default {
                // TODO not supported for now
                revert(0, 0)
            }
        }
    }

    // TODO: remove call to Multivariate.evalMultivariateBytes32(coeffs, ptrToPoint);
    // rather use the present internal fn and pass pointer to folding randomness
    function computeAndCheckFinalFolds(
        bytes32[][] calldata stirChallengesAnswers,
        BN254.ScalarField[] calldata foldingRandomness,
        BN254.ScalarField[] calldata finalCoefficientValues,
        BN254.ScalarField[] calldata finalRandomnessPoints
    ) external pure {
        for (uint256 j = 0; j < stirChallengesAnswers.length; j++) {
            Utils.requireEqualScalars(
                Multivariate.evalMultivariateBytes32(stirChallengesAnswers[j], foldingRandomness),
                Univariate.evaluateUnivariate(finalCoefficientValues, finalRandomnessPoints[j])
            );
        }
    }
}
