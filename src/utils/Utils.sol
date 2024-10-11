// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {BN254} from "solidity-bn254/BN254.sol";

library Utils {
    // we provide a few useful constants used throughout the library
    BN254.ScalarField public constant BN254_TWO_INV =
        BN254.ScalarField.wrap(10944121435919637611123202872628637544274182200208017171849102093287904247809);
    BN254.ScalarField public constant BN254_TWO = BN254.ScalarField.wrap(2);
    BN254.ScalarField public constant BN254_ONE = BN254.ScalarField.wrap(1);
    BN254.ScalarField public constant BN254_MINUS_ONE =
        BN254.ScalarField.wrap(21888242871839275222246405745257275088548364400416034343698204186575808495616);

    function arrayToScalarField(uint256[] memory values) public pure returns (BN254.ScalarField[] memory) {
        BN254.ScalarField[] memory scalars = new BN254.ScalarField[](values.length);
        for (uint256 i = 0; i < values.length; i++) {
            scalars[i] = BN254.ScalarField.wrap(values[i]);
        }
        return scalars;
    }

    function uintToScalarField(uint256 value) public pure returns (BN254.ScalarField) {
        return BN254.ScalarField.wrap(value);
    }

    function arrayScalarFieldToUint(BN254.ScalarField[] memory scalars) public pure returns (uint256[] memory) {
        uint256[] memory values = new uint256[](scalars.length);
        for (uint256 i = 0; i < scalars.length; i++) {
            values[i] = BN254.ScalarField.unwrap(scalars[i]);
        }
        return values;
    }

    function baseDecomposition(uint256 value, uint8 base, uint256 nBits) external pure returns (uint8[] memory) {
        // Initialize the result array with zeros of the specified length
        uint8[] memory result = new uint8[](nBits);

        // Perform base decomposition
        for (uint256 i = 0; i < nBits; i++) {
            result[nBits - 1 - i] = uint8(value % base);
            value /= base;
        }

        return result;
    }

    function arrayUint8ToScalarField(uint8[] memory values) public pure returns (BN254.ScalarField[] memory) {
        BN254.ScalarField[] memory scalars = new BN254.ScalarField[](values.length);
        for (uint256 i = 0; i < values.length; i++) {
            scalars[i] = BN254.ScalarField.wrap(values[i]);
        }
        return scalars;
    }
}
