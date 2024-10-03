// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {BN254} from "solidity-bn254/BN254.sol";

library Utils {
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
}
