// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {BN254} from "solidity-bn254/BN254.sol";
import {EVMFs} from "../fs/FiatShamir.sol";

// @notice polynomials are in F^{<3}[X_1, \dots, X_k]
// it us uniquely determined by it's evaluations over {0, 1, 2}^k
// (notice from whir/sumcheck/proof.rs)
struct SumcheckRound {
    BN254.ScalarField e0;
    BN254.ScalarField e1;
    BN254.ScalarField e2;
    BN254.ScalarField foldingRandomnessSingle;
}

struct SumcheckRound1 {
    BN254.ScalarField foldingRandomnessSingle;
}

library Sumcheck {
    uint256 public constant R_MOD = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    uint256 public constant BN254_MINUS_ONE =
        21888242871839275222246405745257275088548364400416034343698204186575808495616;
    uint256 public constant BN254_MINUS_TWO =
        21888242871839275222246405745257275088548364400416034343698204186575808495615;
    uint256 public constant BN254_TWO_INV =
        10944121435919637611123202872628637544274182200208017171849102093287904247809;

    function getSumcheckRounds_1(
        bytes calldata transcript,
        uint256 cur,
        bytes32 state,
        uint256 powBits,
        BN254.ScalarField claimedSum,
        uint256 nRounds
    )
        external
        pure
        returns (
            uint256,
            bytes32,
            BN254.ScalarField[] memory foldingRandomnessPoint,
            BN254.ScalarField e0,
            BN254.ScalarField e1,
            BN254.ScalarField e2
        )
    {
        foldingRandomnessPoint = new BN254.ScalarField[](nRounds);

        for (uint256 i = 0; i < nRounds;) {
            (cur, state, e0, e1, e2) = EVMFs.nextScalars3(transcript, cur);

            assembly ("memory-safe") {
                // get the single randomness value from squeezing state
                let foldingRandomnessSingle := squeezeScalars1(state)
                let e0_add_e1 := addmod(e0, e1, R_MOD)

                // ensure that they are equal, otherwise revert
                if iszero(eq(claimedSum, e0_add_e1)) { revert(0, 0) }

                // continue sumcheck, compute next claimed sum
                claimedSum := evaluateAtPoint1_3(e0, e1, e2, foldingRandomnessSingle)

                // assign folding randomness to  the foldingRandomnessPoint
                // nRounds * 0x20 gives offset to last point, add it to the address of the point
                // subtract the i elements that we have already assigned (we are going backwards)
                let ptrLastElementPoint := add(foldingRandomnessPoint, mul(0x20, nRounds))
                let ptrPoint := sub(ptrLastElementPoint, mul(0x20, i))
                mstore(ptrPoint, foldingRandomnessSingle)

                function squeezeScalars1(s) -> scalar {
                    mstore(0x00, s)
                    scalar := keccak256(0x00, 0x20)
                }

                // sumcheck utility
                function evaluateAtPoint1_3(e_0, e_1, e_2, point) -> evaluation {
                    let eqPoly3_0_x := addmod(point, BN254_MINUS_ONE, R_MOD)
                    let eqPoly3_0_y := addmod(point, BN254_MINUS_TWO, R_MOD)
                    let eqPoly3_0_z := mulmod(eqPoly3_0_x, eqPoly3_0_y, R_MOD)
                    let eqPoly3_0 := mulmod(eqPoly3_0_z, BN254_TWO_INV, R_MOD)

                    let eqPoly3_1_x := addmod(point, BN254_MINUS_TWO, R_MOD)
                    let eqPoly3_1_y := mulmod(eqPoly3_1_x, BN254_MINUS_ONE, R_MOD)
                    let eqPoly3_1 := mulmod(point, eqPoly3_1_y, R_MOD)

                    let eqPoly3_2_x := addmod(point, BN254_MINUS_ONE, R_MOD)
                    let eqPoly3_2_y := mulmod(eqPoly3_2_x, BN254_TWO_INV, R_MOD)
                    let eqPoly3_2 := mulmod(point, eqPoly3_2_y, R_MOD)

                    evaluation := mulmod(e_0, eqPoly3_0, R_MOD)
                    evaluation := addmod(evaluation, mulmod(e_1, eqPoly3_1, R_MOD), R_MOD)
                    evaluation := addmod(evaluation, mulmod(e_2, eqPoly3_2, R_MOD), R_MOD)
                }
            }

            if (powBits > 0) {
                (cur, state) = EVMFs.checkPow(transcript, cur, state, powBits);
            }

            unchecked {
                ++i;
            }
        }

        return (cur, state, foldingRandomnessPoint, e0, e1, e2);
    }

    // TODO: get rid of this extra implementation, which is used in Whir.sol
    function evaluateAtPoint1_3(
        BN254.ScalarField e0,
        BN254.ScalarField e1,
        BN254.ScalarField e2,
        BN254.ScalarField point
    ) external pure returns (BN254.ScalarField) {
        uint256 evaluation;

        assembly {
            // compute eqPolys
            let eqPoly3_0_x := addmod(point, BN254_MINUS_ONE, R_MOD)
            let eqPoly3_0_y := addmod(point, BN254_MINUS_TWO, R_MOD)
            let eqPoly3_0_z := mulmod(eqPoly3_0_x, eqPoly3_0_y, R_MOD)
            let eqPoly3_0 := mulmod(eqPoly3_0_z, BN254_TWO_INV, R_MOD)

            let eqPoly3_1_x := addmod(point, BN254_MINUS_TWO, R_MOD)
            let eqPoly3_1_y := mulmod(eqPoly3_1_x, BN254_MINUS_ONE, R_MOD)
            let eqPoly3_1 := mulmod(point, eqPoly3_1_y, R_MOD)

            let eqPoly3_2_x := addmod(point, BN254_MINUS_ONE, R_MOD)
            let eqPoly3_2_y := mulmod(eqPoly3_2_x, BN254_TWO_INV, R_MOD)
            let eqPoly3_2 := mulmod(point, eqPoly3_2_y, R_MOD)

            evaluation := mulmod(e0, eqPoly3_0, R_MOD)
            evaluation := addmod(evaluation, mulmod(e1, eqPoly3_1, R_MOD), R_MOD)
            evaluation := addmod(evaluation, mulmod(e2, eqPoly3_2, R_MOD), R_MOD)
        }

        return BN254.ScalarField.wrap(evaluation);
    }
}
