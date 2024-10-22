// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {BN254} from "solidity-bn254/BN254.sol";

import {console} from "forge-std/Test.sol";
import {MultilinearPoint, PolyUtils} from "../../src/poly_utils/PolyUtils.sol";
import {WhirBaseTest} from "../WhirBaseTest.t.sol";

contract PolyUtilsTest is WhirBaseTest {
    // @notice test values from whir repo
    function test_expandFromUnivariate() external pure {
        uint256 numVariables = 4;
        BN254.ScalarField[] memory point = new BN254.ScalarField[](4);
        point[0] = BN254.ScalarField.wrap(256);
        point[1] = BN254.ScalarField.wrap(16);
        point[2] = BN254.ScalarField.wrap(4);
        point[3] = BN254.ScalarField.wrap(2);

        MultilinearPoint memory point2 = PolyUtils.expandFromUnivariate(BN254.ScalarField.wrap(2), numVariables);

        // TODO? Not sure yet to implement from_binary_hypercube_point
        // MultilinearPoint memory point0 = PolyUtils.expandFromUnivariate(BN254.ScalarField.wrap(0), numVariables);
        // MultilinearPoint memory point1 = PolyUtils.expandFromUnivariate(BN254.ScalarField.wrap(1), numVariables);
        //         assert_eq!(
        //           MultilinearPoint::from_binary_hypercube_point(BinaryHypercubePoint(0), num_variables),
        //         point0
        //   );

        assertEqScalarFieldArray(point, point2.point);
    }

    // @notice test value checked against whir implementation
    function test_eqPolyOutside() external pure {
        BN254.ScalarField[] memory coords = new BN254.ScalarField[](2);
        BN254.ScalarField[] memory point = new BN254.ScalarField[](2);
        (coords[0], coords[1]) = (BN254.ScalarField.wrap(42), BN254.ScalarField.wrap(36));
        (point[1], point[0]) = (BN254.ScalarField.wrap(42), BN254.ScalarField.wrap(36));
        assertEqUintScalarField(8684809, PolyUtils.eqPolyOutside(MultilinearPoint(coords), MultilinearPoint(point)));
    }

    // @notice test values from whir repo
    function test_equality3() external pure {
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
