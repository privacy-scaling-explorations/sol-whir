// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {BN254} from "solidity-bn254/BN254.sol";

import {console} from "forge-std/Test.sol";
import {MultilinearPoint, PolyUtils} from "../../src/poly_utils/PolyUtils.sol";
import {WhirBaseTest} from "../WhirBaseTest.t.sol";

contract PolyUtilsTest is WhirBaseTest {
    function test_equality3() public pure {
        BN254.ScalarField[] memory point = new BN254.ScalarField[](2);
        point[0] = BN254.ScalarField.wrap(0);
        point[1] = BN254.ScalarField.wrap(0);
        MultilinearPoint memory mlpoint = PolyUtils.newMultilinearPoint(point);

        assertEqUintScalarField(1, PolyUtils.eqPoly3(mlpoint, 0));
        assertEqUintScalarField(0, PolyUtils.eqPoly3(mlpoint, 1));
        assertEqUintScalarField(0, PolyUtils.eqPoly3(mlpoint, 2));
        assertEqUintScalarField(0, PolyUtils.eqPoly3(mlpoint, 3));
        assertEqUintScalarField(0, PolyUtils.eqPoly3(mlpoint, 4));
        assertEqUintScalarField(0, PolyUtils.eqPoly3(mlpoint, 5));
        assertEqUintScalarField(0, PolyUtils.eqPoly3(mlpoint, 6));
        assertEqUintScalarField(0, PolyUtils.eqPoly3(mlpoint, 7));
        assertEqUintScalarField(0, PolyUtils.eqPoly3(mlpoint, 8));

        mlpoint.point[0] = BN254.ScalarField.wrap(1);
        mlpoint.point[1] = BN254.ScalarField.wrap(0);
        assertEqUintScalarField(0, PolyUtils.eqPoly3(mlpoint, 0));
        assertEqUintScalarField(0, PolyUtils.eqPoly3(mlpoint, 1));
        assertEqUintScalarField(0, PolyUtils.eqPoly3(mlpoint, 2));
        assertEqUintScalarField(1, PolyUtils.eqPoly3(mlpoint, 3));
        assertEqUintScalarField(0, PolyUtils.eqPoly3(mlpoint, 4));
        assertEqUintScalarField(0, PolyUtils.eqPoly3(mlpoint, 5));
        assertEqUintScalarField(0, PolyUtils.eqPoly3(mlpoint, 6));
        assertEqUintScalarField(0, PolyUtils.eqPoly3(mlpoint, 7));
        assertEqUintScalarField(0, PolyUtils.eqPoly3(mlpoint, 8));

        mlpoint.point[0] = BN254.ScalarField.wrap(0);
        mlpoint.point[1] = BN254.ScalarField.wrap(2);
        assertEqUintScalarField(0, PolyUtils.eqPoly3(mlpoint, 0));
        assertEqUintScalarField(0, PolyUtils.eqPoly3(mlpoint, 1));
        assertEqUintScalarField(1, PolyUtils.eqPoly3(mlpoint, 2));
        assertEqUintScalarField(0, PolyUtils.eqPoly3(mlpoint, 3));
        assertEqUintScalarField(0, PolyUtils.eqPoly3(mlpoint, 4));
        assertEqUintScalarField(0, PolyUtils.eqPoly3(mlpoint, 5));
        assertEqUintScalarField(0, PolyUtils.eqPoly3(mlpoint, 6));
        assertEqUintScalarField(0, PolyUtils.eqPoly3(mlpoint, 7));
        assertEqUintScalarField(0, PolyUtils.eqPoly3(mlpoint, 8));

        mlpoint.point[0] = BN254.ScalarField.wrap(2);
        mlpoint.point[1] = BN254.ScalarField.wrap(2);
        assertEqUintScalarField(0, PolyUtils.eqPoly3(mlpoint, 0));
        assertEqUintScalarField(0, PolyUtils.eqPoly3(mlpoint, 1));
        assertEqUintScalarField(0, PolyUtils.eqPoly3(mlpoint, 2));
        assertEqUintScalarField(0, PolyUtils.eqPoly3(mlpoint, 3));
        assertEqUintScalarField(0, PolyUtils.eqPoly3(mlpoint, 4));
        assertEqUintScalarField(0, PolyUtils.eqPoly3(mlpoint, 5));
        assertEqUintScalarField(0, PolyUtils.eqPoly3(mlpoint, 6));
        assertEqUintScalarField(0, PolyUtils.eqPoly3(mlpoint, 7));
        assertEqUintScalarField(1, PolyUtils.eqPoly3(mlpoint, 8));
    }
}
