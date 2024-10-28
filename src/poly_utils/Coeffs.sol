// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {BN254} from "solidity-bn254/BN254.sol";

library Multivariate {
    uint256 internal constant R_MOD = 21888242871839275222246405745257275088548364400416034343698204186575808495617;

    // TODO: we would like to remove this, though it is still used in VerifierUtils
    function evalMultivariateBytes32(bytes32[] calldata coeffs, BN254.ScalarField[] calldata point)
        external
        pure
        returns (BN254.ScalarField res)
    {
        uint256 length;
        assembly {
            length := point.length
            switch point.length
            case 0 { res := calldataload(coeffs.offset) }
            case 1 {
                let c0 := calldataload(coeffs.offset)
                let c1 := calldataload(add(coeffs.offset, 0x20))
                let p0 := calldataload(point.offset)
                res := addmod(c0, mulmod(c1, p0, R_MOD), R_MOD)
            }
            case 2 {
                let c0 := calldataload(coeffs.offset)
                let c1 := calldataload(add(coeffs.offset, 0x20))
                let c2 := calldataload(add(coeffs.offset, 0x40))
                let c3 := calldataload(add(coeffs.offset, 0x60))
                let p0 := calldataload(point.offset)
                let p1 := calldataload(add(point.offset, 0x20))
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
                let p0 := calldataload(point.offset)
                let p1 := calldataload(add(point.offset, 0x20))
                let p2 := calldataload(add(point.offset, 0x40))
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
                let p0 := calldataload(point.offset)
                let p1 := calldataload(add(point.offset, 0x20))
                let p2 := calldataload(add(point.offset, 0x40))
                let p3 := calldataload(add(point.offset, 0x60))

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

    function evalMultivariate(BN254.ScalarField[] calldata coeffs, BN254.ScalarField[] calldata point)
        external
        pure
        returns (BN254.ScalarField)
    {
        return Coeffs._evalMultivariate(coeffs, point);
    }
}

library Univariate {
    // naive univariate polynomial evaluation
    function _evaluateUnivariate(BN254.ScalarField[] calldata coeffs, BN254.ScalarField point)
        internal
        pure
        returns (BN254.ScalarField)
    {
        BN254.ScalarField eval = BN254.ScalarField.wrap(0);
        BN254.ScalarField x = BN254.ScalarField.wrap(1);
        for (uint256 i = 0; i < coeffs.length; i++) {
            eval = BN254.add(eval, BN254.mul(x, coeffs[i]));
            x = BN254.mul(x, point);
        }
        return eval;
    }

    function evaluateUnivariate(BN254.ScalarField[] calldata coeffs, BN254.ScalarField point)
        external
        pure
        returns (BN254.ScalarField)
    {
        if (coeffs.length == 0) {
            return BN254.ScalarField.wrap(0);
        } else {
            return _evaluateUnivariate(coeffs, point);
        }
    }
}

library Coeffs {
    function eval1Bytes32(bytes32[] calldata coeffs, BN254.ScalarField[] calldata point)
        internal
        pure
        returns (BN254.ScalarField)
    {
        return BN254.add(
            BN254.ScalarField.wrap(uint256(coeffs[0])), BN254.mul(BN254.ScalarField.wrap(uint256(coeffs[1])), point[0])
        );
    }

    function eval1(BN254.ScalarField[] calldata coeffs, BN254.ScalarField[] calldata point)
        internal
        pure
        returns (BN254.ScalarField)
    {
        return BN254.add(coeffs[0], BN254.mul(coeffs[1], point[0]));
    }

    function eval2(BN254.ScalarField[] calldata coeffs, BN254.ScalarField[] calldata point)
        internal
        pure
        returns (BN254.ScalarField)
    {
        BN254.ScalarField b0 = BN254.add(coeffs[0], BN254.mul(coeffs[1], point[1]));
        BN254.ScalarField b1 = BN254.add(coeffs[2], BN254.mul(coeffs[3], point[1]));
        return BN254.add(b0, BN254.mul(b1, point[0]));
    }

    function eval3(BN254.ScalarField[] calldata coeffs, BN254.ScalarField[] calldata point)
        internal
        pure
        returns (BN254.ScalarField)
    {
        BN254.ScalarField b00 = BN254.add(coeffs[0], BN254.mul(coeffs[1], point[2]));
        BN254.ScalarField b01 = BN254.add(coeffs[2], BN254.mul(coeffs[3], point[2]));
        BN254.ScalarField b10 = BN254.add(coeffs[4], BN254.mul(coeffs[5], point[2]));
        BN254.ScalarField b11 = BN254.add(coeffs[6], BN254.mul(coeffs[7], point[2]));
        BN254.ScalarField b0 = BN254.add(b00, BN254.mul(b01, point[1]));
        BN254.ScalarField b1 = BN254.add(b10, BN254.mul(b11, point[1]));
        return BN254.add(b0, BN254.mul(b1, point[0]));
    }

    function eval4(BN254.ScalarField[] calldata coeffs, BN254.ScalarField[] calldata point)
        internal
        pure
        returns (BN254.ScalarField)
    {
        BN254.ScalarField b00 = BN254.add(
            BN254.add(coeffs[0], BN254.mul(coeffs[1], point[3])),
            BN254.mul(BN254.add(coeffs[2], BN254.mul(coeffs[3], point[3])), point[2])
        );
        BN254.ScalarField b01 = BN254.add(
            BN254.add(coeffs[4], BN254.mul(coeffs[5], point[3])),
            BN254.mul(BN254.add(coeffs[6], BN254.mul(coeffs[7], point[3])), point[2])
        );
        BN254.ScalarField b10 = BN254.add(
            BN254.add(coeffs[8], BN254.mul(coeffs[9], point[3])),
            BN254.mul(BN254.add(coeffs[10], BN254.mul(coeffs[11], point[3])), point[2])
        );
        BN254.ScalarField b11 = BN254.add(
            BN254.add(coeffs[12], BN254.mul(coeffs[13], point[3])),
            BN254.mul(BN254.add(coeffs[14], BN254.mul(coeffs[15], point[3])), point[2])
        );
        BN254.ScalarField b0 = BN254.add(b00, BN254.mul(b01, point[1]));
        BN254.ScalarField b1 = BN254.add(b10, BN254.mul(b11, point[1]));
        return BN254.add(b0, BN254.mul(b1, point[0]));
    }

    // @dev Follows the implementation from https://github.com/WizardOfMenlo/whir/blob/cb3de2c886804b0cac022738479b931916bd57c1/src/poly_utils/coeffs.rs#L123
    // We slightly depart from the corresponding signature, mainly for avoiding passing down the `CoefficientList` struct
    function _evalMultivariate(BN254.ScalarField[] calldata coeffs, BN254.ScalarField[] calldata point)
        internal
        pure
        returns (BN254.ScalarField)
    {
        if (point.length == 0) {
            return coeffs[0];
        } else if (point.length == 1) {
            return eval1(coeffs, point);
        } else if (point.length == 2) {
            return eval2(coeffs, point);
        } else if (point.length == 3) {
            return eval3(coeffs, point);
        } else if (point.length == 4) {
            return eval4(coeffs, point);
        } else {
            uint256 coeffsSplit = coeffs.length / 2;
            BN254.ScalarField[] memory tailPoint = new BN254.ScalarField[](point.length - 1);
            for (uint256 i = 1; i < point.length; i++) {
                tailPoint[i - 1] = point[i];
            }

            BN254.ScalarField[] memory b0t = new BN254.ScalarField[](coeffsSplit);
            BN254.ScalarField[] memory b1t = new BN254.ScalarField[](coeffsSplit);
            for (uint256 i = 0; i < coeffsSplit; i++) {
                b0t[i] = coeffs[i];
                b1t[i] = coeffs[i + coeffsSplit];
            }
            BN254.ScalarField b0tEval = Multivariate.evalMultivariate(b0t, tailPoint);
            BN254.ScalarField b1tEval = Multivariate.evalMultivariate(b1t, tailPoint);
            return BN254.add(b0tEval, BN254.mul(b1tEval, point[0]));
        }
    }
}
