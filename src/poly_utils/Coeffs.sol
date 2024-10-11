// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {BN254} from "solidity-bn254/BN254.sol";
import {Test, console} from "forge-std/Test.sol";
import {MultilinearPoint} from "../poly_utils/PolyUtils.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

struct CoefficientList {
    BN254.ScalarField[] coeffs;
    uint256 numVariables;
}

library Coeffs {
    // naive univariate polynomial evaluation
    function _evaluateUnivariate(BN254.ScalarField[] memory coeffs, BN254.ScalarField point)
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

    function evaluateUnivariate(BN254.ScalarField[] memory coeffs, BN254.ScalarField point)
        internal
        pure
        returns (BN254.ScalarField)
    {
        if (coeffs.length == 0) {
            return BN254.ScalarField.wrap(0);
        } else {
            return _evaluateUnivariate(coeffs, point);
        }
    }

    // @notice interprets coeffs as coeffs of a univariate polynomial
    // and returns the evaluation of this univariate polynomial at each of those points
    function evaluateAtUnivariate(CoefficientList memory coeffs, BN254.ScalarField[] memory points)
        external
        pure
        returns (BN254.ScalarField[] memory)
    {
        BN254.ScalarField[] memory evaluations = new BN254.ScalarField[](points.length);
        for (uint256 i = 0; i < points.length; i++) {
            evaluations[i] = evaluateUnivariate(coeffs.coeffs, points[i]);
        }
        return evaluations;
    }

    // @notice Initiates a new coefficient list struct
    function newCoefficientList(BN254.ScalarField[] memory coeffs) external pure returns (CoefficientList memory) {
        uint256 nVariables = Math.log2(coeffs.length);
        return CoefficientList(coeffs, nVariables);
    }

    // @notice Utility function for getting a particular chunk from an array
    function getChunk(BN254.ScalarField[] memory array, uint256 start, uint256 end)
        internal
        pure
        returns (BN254.ScalarField[] memory)
    {
        require(end > start && end <= array.length, "Invalid start or end index");
        BN254.ScalarField[] memory chunk = new BN254.ScalarField[](end - start);
        for (uint256 i = start; i < end; i++) {
            chunk[i - start] = array[i];
        }
        return chunk;
    }

    // @notice computes folding
    function fold(CoefficientList memory coeffs, MultilinearPoint memory foldingRandomness)
        external
        returns (CoefficientList memory)
    {
        uint256 chunkSize = 1 << foldingRandomness.point.length;
        uint256 nChunks = coeffs.coeffs.length / chunkSize;
        BN254.ScalarField[] memory newCoeffs = new BN254.ScalarField[](nChunks);
        for (uint256 chunkIdx = 0; chunkIdx < nChunks; chunkIdx++) {
            uint256 start = chunkIdx * chunkSize;
            uint256 end = chunkSize * (chunkIdx + 1);
            BN254.ScalarField[] memory coeffChunk = getChunk(coeffs.coeffs, start, end);
            BN254.ScalarField coeff = evalMultivariate(coeffChunk, foldingRandomness.point);
            newCoeffs[chunkIdx] = coeff;
        }
        return CoefficientList({coeffs: newCoeffs, numVariables: coeffs.numVariables - foldingRandomness.point.length});
    }

    // @notice eval functions are internal, they are used only in the context of the evaluation of a multivariate polynomial
    function eval0(BN254.ScalarField[] memory coeffs) internal pure returns (BN254.ScalarField) {
        return coeffs[0];
    }

    function eval1(BN254.ScalarField[] memory coeffs, BN254.ScalarField[] memory point)
        internal
        pure
        returns (BN254.ScalarField)
    {
        return BN254.add(coeffs[0], BN254.mul(coeffs[1], point[0]));
    }

    function eval2(BN254.ScalarField[] memory coeffs, BN254.ScalarField[] memory point)
        internal
        pure
        returns (BN254.ScalarField)
    {
        BN254.ScalarField b0 = BN254.add(coeffs[0], BN254.mul(coeffs[1], point[1]));
        BN254.ScalarField b1 = BN254.add(coeffs[2], BN254.mul(coeffs[3], point[1]));
        return BN254.add(b0, BN254.mul(b1, point[0]));
    }

    function eval3(BN254.ScalarField[] memory coeffs, BN254.ScalarField[] memory point)
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

    function eval4(BN254.ScalarField[] memory coeffs, BN254.ScalarField[] memory point)
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

    // @notice Follows the implementation from https://github.com/WizardOfMenlo/whir/blob/cb3de2c886804b0cac022738479b931916bd57c1/src/poly_utils/coeffs.rs#L123
    // We slightly depart from the corresponding signature, mainly for avoiding passing down the `CoefficientList` struct
    function evalMultivariate(BN254.ScalarField[] memory coeffs, BN254.ScalarField[] memory point)
        public
        returns (BN254.ScalarField)
    {
        if (point.length == 0) {
            return eval0(coeffs);
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
            BN254.ScalarField b0tEval = evalMultivariate(b0t, tailPoint);
            BN254.ScalarField b1tEval = evalMultivariate(b1t, tailPoint);
            return BN254.add(b0tEval, BN254.mul(b1tEval, point[0]));
        }
    }
}
