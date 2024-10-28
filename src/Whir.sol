// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/*
                     /$$                       /$$       /$$
                    | $$                      | $$      |__/
  /$$$$$$$  /$$$$$$ | $$         /$$  /$$  /$$| $$$$$$$  /$$  /$$$$$$ 
 /$$_____/ /$$__  $$| $$ /$$$$$$| $$ | $$ | $$| $$__  $$| $$ /$$__  $$
|  $$$$$$ | $$  \ $$| $$|______/| $$ | $$ | $$| $$  \ $$| $$| $$  \__/
 \____  $$| $$  | $$| $$        | $$ | $$ | $$| $$  | $$| $$| $$
 /$$$$$$$/|  $$$$$$/| $$        |  $$$$$/$$$$/| $$  | $$| $$| $$
|_______/  \______/ |__/         \_____/\___/ |__/  |__/|__/|__/ 
*/

import {VerifierUtils} from "./verifier_utils/VerifierUtils.sol";
import {WhirProof, Statement, WhirConfig, ParsedRound} from "./WhirStructs.sol";
import {StirUtils} from "./utils/Stir.sol";
import {EVMFs} from "./fs/FiatShamir.sol";
import {Utils} from "./utils/Utils.sol";
import {MerkleVerifier} from "./merkle/MerkleVerifier.sol";
import {Multivariate} from "./poly_utils/Coeffs.sol";
import {Sumcheck, SumcheckRound} from "./sumcheck/Proof.sol";
import {BN254} from "solidity-bn254/BN254.sol";
import {LibSort} from "solady/src/utils/LibSort.sol";

library Verifier {
    uint256 internal constant R_MOD = 21888242871839275222246405745257275088548364400416034343698204186575808495617;

    function verify(
        WhirConfig calldata config,
        Statement calldata statement,
        WhirProof calldata whirProof,
        bytes calldata transcript
    ) external pure returns (bool) {
        (
            uint256 cur,
            bytes32 state,
            ParsedRound[] memory parsedRounds,
            bytes32 prevRoot,
            uint256 domainSize,
            BN254.ScalarField[] memory foldingRandomnessPoint,
            BN254.ScalarField expDomainGen,
            BN254.ScalarField e0,
            BN254.ScalarField e1,
            BN254.ScalarField e2,
            BN254.ScalarField[] memory oodPoints,
            BN254.ScalarField[] memory initialCombinationRandomness,
            BN254.ScalarField randomness
        ) = VerifierUtils.parseRounds(
            transcript,
            0,
            0x0,
            config,
            statement.points.length,
            statement.evaluations,
            whirProof,
            config.domainSize,
            config.expDomainGen
        );

        BN254.ScalarField[] memory finalCoefficientsValues;
        (cur, state, finalCoefficientsValues) =
            EVMFs.nextScalars(transcript, cur, uint128(1) << config.finalSumcheckRounds);

        // get final random index challenges
        uint256[] memory finalRandomnessIndexes =
            EVMFs.squeezeRangedUints(state, config.finalQueries, domainSize / (1 << config.foldingFactor));
        LibSort.sort(finalRandomnessIndexes);
        LibSort.uniquifySorted(finalRandomnessIndexes);
        BN254.ScalarField[] memory finalRandomnessPoints =
            StirUtils.getStirChallengePoints(finalRandomnessIndexes, expDomainGen);

        // verify last merkle round
        uint256 merkleRound = whirProof.merkleProofs.length - 1;
        MerkleVerifier.verify(
            prevRoot,
            whirProof.merkleProofs[merkleRound].depth,
            finalRandomnessIndexes,
            whirProof.answers[merkleRound],
            whirProof.merkleProofs[merkleRound].decommitments
        );

        // pow check
        if (config.finalPowBits > 0) {
            (cur, state) = EVMFs.checkPow(transcript, cur, state, config.finalPowBits);
        }

        // check the foldings computed from the proof match evaluations of the polynomial
        VerifierUtils.computeAndCheckFinalFolds(
            whirProof.answers[whirProof.answers.length - 1],
            foldingRandomnessPoint,
            finalCoefficientsValues,
            finalRandomnessPoints
        );

        // prepare computation of the v polynomial
        // compute size required to build the multilinear point
        // The size of the point also requires to know the size of each folding randomness point
        uint256 numVariables = config.numVariables;
        uint256 foldingFactor = config.foldingFactor;
        uint256 nRounds = config.roundParameters.length;
        uint256 finalSumcheckRandomnessPointLength = config.finalSumcheckRounds;
        uint256 foldingRandomnessLength = finalSumcheckRandomnessPointLength + foldingFactor * (1 + nRounds);

        BN254.ScalarField[] memory foldingRandomnessNew = new BN254.ScalarField[](foldingRandomnessLength);

        BN254.ScalarField finalCoefficientsValuesMultivariateEval;

        // check final sumcheck if needed
        // if that's the case, start to populate the final randomness array
        // and compute the multivariate evaluation
        if (config.finalSumcheckRounds > 0) {
            BN254.ScalarField[] memory finalSumcheckRandomnessPoint =
                new BN254.ScalarField[](config.finalSumcheckRounds);

            // compute the claimed sum and go over the sumcheck rounds
            BN254.ScalarField claimedSum = Sumcheck.evaluateAtPoint1_3(e0, e1, e2, randomness);
            (cur, state, finalSumcheckRandomnessPoint, e0, e1, e2) = Sumcheck.getSumcheckRounds_1(
                transcript, cur, state, config.finalFoldingPowBits, claimedSum, config.finalSumcheckRounds
            );
            randomness = finalSumcheckRandomnessPoint[0];

            // TODO: allocate to folding randomness new using asm
            // start to populate the folding randomness
            for (uint256 i = 0; i < finalSumcheckRandomnessPoint.length; i++) {
                foldingRandomnessNew[i] = finalSumcheckRandomnessPoint[i];
            }

            finalCoefficientsValuesMultivariateEval =
                Multivariate.evalMultivariate(finalCoefficientsValues, finalSumcheckRandomnessPoint);
        } else {
            // if there is no final sumcheck, the multivariate eval just consists in the first coeff
            finalCoefficientsValuesMultivariateEval = finalCoefficientsValues[0];
        }

        // initialize pointer to the new/final folding randomness point
        uint256 foldingRandomnessNewPtr;

        // used when computating the v polynomial
        BN254.ScalarField value;

        assembly ("memory-safe") {
            // we continue allocating values to foldingRandomnessNew
            foldingRandomnessNewPtr := foldingRandomnessNew

            // add 0x20 to avoid pointing to the length
            let pointNewPtr := add(foldingRandomnessNewPtr, 0x20)
            let pointRandomnessPtr := add(foldingRandomnessPoint, 0x20)

            //  the final sumcheck randomness point will come before it in the new folding randomness point
            let offsetFromFinalSumcheckRandomness := mul(0x20, finalSumcheckRandomnessPointLength)
            pointNewPtr := add(pointNewPtr, offsetFromFinalSumcheckRandomness)

            for { let i := 0 } lt(i, foldingFactor) { i := add(i, 1) } {
                // assign folding randomness obtained at the last sumcheck to the new folding randomness
                mstore(add(pointNewPtr, mul(i, 0x20)), mload(add(pointRandomnessPtr, mul(i, 0x20))))
            }

            // now access rounds and assign folding randomness from the rounds to the final randomness point
            // note that we populate the final randomness vector in the reverse order our rounds occured
            // hence, set the pointer to the end of the parsed rounds array
            let parsedRoundsPtr := add(parsedRounds, mul(nRounds, 0x20))

            for { let r := 0 } lt(r, nRounds) { r := add(r, 1) } {
                let curRoundPtr := mload(parsedRoundsPtr)
                // the pointer to the folding randomness comes first in the ParsedRound struct (see struct def)
                let foldingRandomnessPtr := mload(curRoundPtr)
                foldingRandomnessPtr := add(foldingRandomnessPtr, 0x20) // avoid pointing to the length of folding randomness

                for { let j := 0 } lt(j, foldingFactor) { j := add(j, 1) } {
                    // pointer to the new folding randomness point has already taken into account the offset from the  final sumcheck rounds
                    // we access it at index j, to which we add `r` rounds with points of length `foldingFactor`
                    // foldingRandomnessNew[foldingFactor * (1 + r) + j + finalSumcheckRandomnessPointLength] = point[j];
                    let offsetPreviousPoints := mul(0x20, mul(foldingFactor, add(1, r)))
                    let offsetIdx := mul(0x20, j)
                    let totalOffset := add(offsetPreviousPoints, offsetIdx)
                    mstore(add(pointNewPtr, totalOffset), mload(add(foldingRandomnessPtr, mul(0x20, j))))
                }

                parsedRoundsPtr := sub(parsedRoundsPtr, 0x20)
            }

            // !! we are done with filling up the new folding randomness point !!
            // we can start to compute the v polynomial, starting with the sum of claims
            value := 0

            // load the number of rounds that we will go over
            let ptrParsedRounds := parsedRounds
            let nParsedRounds := mload(ptrParsedRounds)
            let roundNumVariables := numVariables

            // let's allocate an array in memory
            // we will re-use it to allocate values when performing univariate expansions
            // those expansions that we will do below will never be higher that the number of variables
            let ptrUnivariateExpansion := mload(0x40)
            mstore(ptrUnivariateExpansion, numVariables)
            let addedValuesToMem := mul(0x20, add(1, numVariables))
            mstore(0x40, add(ptrUnivariateExpansion, addedValuesToMem)) // update the free mem pointer now

            for { let i := 0 } lt(i, nParsedRounds) { i := add(i, 1) } {
                roundNumVariables := sub(roundNumVariables, foldingFactor)

                // load pointer to round i
                let ptrRound_i := mload(add(ptrParsedRounds, mul(0x20, add(i, 1))))

                // using the ptr to the round, load pointer to ood points, combination randomness, stir challenge points
                // we have ParsedRound (foldingRandomness, oodPoints, stirChallengePoints, combinationRandomness)
                // pointer is located at:      0x00          0x20           0x40             0x60
                let ptrOodPoints := mload(add(ptrRound_i, 0x20))
                let ptrStirChallengePoints := mload(add(ptrRound_i, 0x40))
                let ptrCombinationRandomness := mload(add(ptrRound_i, 0x60))

                let sumOfClaims := 0
                let oodPointsLength := mload(ptrOodPoints)

                for { let j := 0 } lt(j, oodPointsLength) { j := add(j, 1) } {
                    let jOffset := mul(0x20, add(j, 1))

                    // get the j-th point from the ood and combination randomness points
                    let oodPoint_j := mload(add(ptrOodPoints, jOffset))
                    let combRand_j := mload(add(ptrCombinationRandomness, jOffset))

                    expandFromUnivariateBN(oodPoint_j, roundNumVariables, ptrUnivariateExpansion)
                    let point := eqPolyOutside(foldingRandomnessNewPtr, roundNumVariables, ptrUnivariateExpansion)

                    // accumulate in the current sum of claims
                    sumOfClaims := addmod(sumOfClaims, mulmod(point, combRand_j, R_MOD), R_MOD)
                }

                // we will now iterate over the stir challenge points
                let stirChallengePointsLength := mload(ptrStirChallengePoints)
                for { let j := 0 } lt(j, stirChallengePointsLength) { j := add(j, 1) } {
                    let jOffset := mul(0x20, add(j, 1))

                    // get the j-th stir challenge point
                    let stirChallengePoint_j := mload(add(ptrStirChallengePoints, jOffset))

                    expandFromUnivariateBN(stirChallengePoint_j, roundNumVariables, ptrUnivariateExpansion)
                    let point := eqPolyOutside(foldingRandomnessNewPtr, roundNumVariables, ptrUnivariateExpansion)

                    // we want to load the combinationRandomness[j + oodPoints.length] point
                    let combRandomness_j_plus_length :=
                        mload(add(ptrCombinationRandomness, add(jOffset, mul(oodPointsLength, 0x20))))

                    // accumulate in the sum of claims
                    sumOfClaims := addmod(sumOfClaims, mulmod(point, combRandomness_j_plus_length, R_MOD), R_MOD)
                }

                value := addmod(value, sumOfClaims, R_MOD)
            }

            // continue to accumulate value
            let oodPointsLength := mload(oodPoints)
            let oodPointsPtr := add(oodPoints, 0x20)
            let initialCombinationRandomnessPtr := add(initialCombinationRandomness, 0x20)

            for { let i := 0 } lt(i, oodPointsLength) { i := add(i, 1) } {
                let oodPoint_i := mload(add(oodPointsPtr, mul(i, 0x20)))
                let initialCombinationRandomness_i := mload(add(initialCombinationRandomnessPtr, mul(i, 0x20)))

                // compute the univariate expansion
                expandFromUnivariateBN(oodPoint_i, numVariables, ptrUnivariateExpansion)
                let point := eqPolyOutside(ptrUnivariateExpansion, numVariables, foldingRandomnessNewPtr)

                value := addmod(value, mulmod(initialCombinationRandomness_i, point, R_MOD), R_MOD)
            }

            // point is a value to start the univariate expansion from
            // nVars is the number of variables the expansion has
            // rPtr is a pointer to an array to fill up with the expansion
            // we re-use rPtr each time to avoid expanding mem
            function expandFromUnivariateBN(point, nVars, rPtr) {
                let curPoint := point
                // we start to assign from the last element of result
                // we do not load the length of the array, rather take nVars
                // since we re-use the rPtr for different values of nVars
                let resultPtr := add(rPtr, mul(0x20, nVars))
                for { let i := nVars } gt(i, 0) { i := sub(i, 1) } {
                    mstore(resultPtr, curPoint)
                    curPoint := mulmod(curPoint, curPoint, R_MOD)
                    resultPtr := sub(resultPtr, 0x20)
                }
            }

            // cPtr and pPtr are pointers to arrays
            function eqPolyOutside(cPtr, n, pPtr) -> acc {
                acc := 1
                let one := 1
                let nCoords := n
                let coordsPtr := add(cPtr, 0x20) // avoid pointing to length
                let pointPtr := add(pPtr, 0x20) // avoid pointing to length
                for { let i := 0 } lt(i, nCoords) { i := add(i, 1) } {
                    let l := mload(coordsPtr)
                    let r := mload(pointPtr)
                    let a := mulmod(l, r, R_MOD)
                    // sub(R_MOD, mod(l, R_MOD)) --> negate(l)
                    let b := addmod(one, sub(R_MOD, mod(l, R_MOD)), R_MOD)
                    let c := addmod(one, sub(R_MOD, mod(r, R_MOD)), R_MOD)
                    acc := mulmod(acc, addmod(a, mulmod(b, c, R_MOD), R_MOD), R_MOD)
                    coordsPtr := add(coordsPtr, 0x20)
                    pointPtr := add(pointPtr, 0x20)
                }
            }
        }

        uint256 oodPointsLength = oodPoints.length;

        // TODO: break up the statement struct to access points
        for (uint256 i = 0; i < statement.points.length; i++) {
            value = BN254.add(
                value,
                BN254.mul(
                    initialCombinationRandomness[oodPointsLength + i],
                    // we pass pointer to the new folding randomness point instead of the point itself
                    eqPolyOutside(statement.points[i], foldingRandomnessNewPtr)
                )
            );
        }

        // end computation of the v polynomial

        Utils.requireEqualScalars(
            Sumcheck.evaluateAtPoint1_3(e0, e1, e2, randomness),
            BN254.mul(value, finalCoefficientsValuesMultivariateEval)
        );
        return true;
    }

    function eqPolyOutside(BN254.ScalarField[] calldata coords, uint256 arrPtr)
        internal
        pure
        returns (BN254.ScalarField acc)
    {
        assembly ("memory-safe") {
            let nCoords := coords.length
            acc := 1
            let coordsPtr := coords.offset
            let pointPtr := add(arrPtr, 0x20) // advance by 1 to not point to length
            for { let i := 0 } lt(i, nCoords) { i := add(i, 1) } {
                let l := calldataload(coordsPtr)
                let r := mload(pointPtr)
                let a := mulmod(l, r, R_MOD)
                // sub(R_MOD, mod(l, R_MOD)) --> negate(l)
                let b := addmod(1, sub(R_MOD, mod(l, R_MOD)), R_MOD)
                let c := addmod(1, sub(R_MOD, mod(r, R_MOD)), R_MOD)
                acc := mulmod(acc, addmod(a, mulmod(b, c, R_MOD), R_MOD), R_MOD)
                coordsPtr := add(coordsPtr, 0x20)
                pointPtr := add(pointPtr, 0x20)
            }
        }
    }
}
