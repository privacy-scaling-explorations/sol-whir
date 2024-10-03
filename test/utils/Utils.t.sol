// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {BN254} from "solidity-bn254/BN254.sol";
import {Test} from "forge-std/Test.sol";

contract Utils is Test {
    function assertEqScalarField(BN254.ScalarField a, BN254.ScalarField b) public pure {
        assertEq(BN254.ScalarField.unwrap(a), BN254.ScalarField.unwrap(b));
    }

    function assertEqUintScalarField(uint256 a, BN254.ScalarField b) public pure {
        assertEq(a, BN254.ScalarField.unwrap(b));
    }
}
