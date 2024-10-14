// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {BN254} from "solidity-bn254/BN254.sol";

import {WhirBaseTest} from "./WhirBaseTest.t.sol";
import {VerifierUtils} from "../src/Verifier.sol";

contract VerifierTest is WhirBaseTest {
    // @notice custom test, checked against whir repo
    function test_expandRandomness() external pure {
        BN254.ScalarField base = BN254.ScalarField.wrap(2);
        BN254.ScalarField[] memory res = VerifierUtils.expandRandomness(base, 5);
        assertEqUintScalarField(1, res[0]);
        assertEqUintScalarField(2, res[1]);
        assertEqUintScalarField(4, res[2]);
        assertEqUintScalarField(8, res[3]);
        assertEqUintScalarField(16, res[4]);
    }
}
