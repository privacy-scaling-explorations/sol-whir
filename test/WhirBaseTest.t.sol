// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {BN254} from "solidity-bn254/BN254.sol";

// @notice Test contracts inherit from this Base contract, providing a few useful helper methods
// TODO: call arkworks with ffi instead of harcoding
contract WhirBaseTest is Test {
    function assertEqScalarField(BN254.ScalarField a, BN254.ScalarField b) public pure {
        assertEq(BN254.ScalarField.unwrap(a), BN254.ScalarField.unwrap(b));
    }

    function assertEqUintScalarField(uint256 a, BN254.ScalarField b) public pure {
        assertEq(a, BN254.ScalarField.unwrap(b));
    }

    function assertEqUint8Array(uint8[] memory a, uint8[] memory b) public pure {
        for (uint256 i = 0; i < a.length; i++) {
            assertEq(a[i], b[i]);
        }
    }
}
