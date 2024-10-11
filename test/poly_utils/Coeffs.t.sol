// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {BN254} from "solidity-bn254/BN254.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import "../../src/utils/Utils.sol";
import {Coeffs, CoefficientList} from "../../src/poly_utils/Coeffs.sol";
import {MultilinearPoint} from "../../src/poly_utils/PolyUtils.sol";
import {WhirBaseTest} from "../WhirBaseTest.t.sol";

contract CoeffsTest is WhirBaseTest {
    uint256 MAX_ARR_SIZE = 10;

    // @notice test values from whir repo
    function test_folding() external {
        uint256[] memory coeffs = new uint256[](4);
        coeffs[0] = uint256(22);
        coeffs[1] = 5;
        coeffs[2] = 0;
        coeffs[3] = 0;

        uint256[] memory alpha = new uint256[](1);
        uint256[] memory beta = new uint256[](1);
        alpha[0] = uint256(100);
        beta[0] = uint256(32);

        BN254.ScalarField[] memory point = new BN254.ScalarField[](2);
        point[0] = BN254.ScalarField.wrap(alpha[0]);
        point[1] = BN254.ScalarField.wrap(beta[0]);

        CoefficientList memory coeffsList = Coeffs.newCoefficientList(Utils.arrayToScalarField(coeffs));
        MultilinearPoint memory foldingRandomness = MultilinearPoint(Utils.arrayToScalarField(beta));
        CoefficientList memory folded = Coeffs.fold(coeffsList, foldingRandomness);

        // matched against whir repo
        assertEqUintScalarField(182, folded.coeffs[0]);
        assertEqUintScalarField(0, folded.coeffs[1]);

        BN254.ScalarField eval = Coeffs.evalMultivariate(coeffsList.coeffs, point);
        BN254.ScalarField evalFolded = Coeffs.evalMultivariate(folded.coeffs, Utils.arrayToScalarField(alpha));

        assertEqScalarField(eval, evalFolded);
    }

    // @notice test values from whir repo
    // custom test, with a larger folding point, crossed check with whir implementation
    // would be better to do this with ffi; see TODO
    function test_folding_2() external {
        uint256[] memory coeffs = new uint256[](8);
        coeffs[0] = uint256(22);
        coeffs[1] = 5;
        coeffs[2] = 0;
        coeffs[3] = 0;
        coeffs[4] = uint256(22);
        coeffs[5] = 5;
        coeffs[6] = 0;
        coeffs[7] = 0;

        uint256[] memory alpha = new uint256[](1);
        uint256[] memory beta_gamma = new uint256[](2);
        alpha[0] = uint256(4);
        beta_gamma[0] = uint256(42);
        beta_gamma[1] = uint256(24);

        BN254.ScalarField[] memory point = new BN254.ScalarField[](3);
        point[0] = BN254.ScalarField.wrap(alpha[0]);
        point[1] = BN254.ScalarField.wrap(beta_gamma[0]);
        point[2] = BN254.ScalarField.wrap(beta_gamma[1]);

        CoefficientList memory coeffsList = Coeffs.newCoefficientList(Utils.arrayToScalarField(coeffs));
        MultilinearPoint memory foldingRandomness = MultilinearPoint(Utils.arrayToScalarField(beta_gamma));
        CoefficientList memory folded = Coeffs.fold(coeffsList, foldingRandomness);

        BN254.ScalarField eval = Coeffs.evalMultivariate(coeffsList.coeffs, point);
        BN254.ScalarField evalFolded = Coeffs.evalMultivariate(folded.coeffs, Utils.arrayToScalarField(alpha));
        assertEqScalarField(eval, evalFolded);
        // matched against whir repo
        assertEqUintScalarField(710, evalFolded);
    }

    // @notice test values were matched against the whir repo
    // ideally, we would like to do this using ffi (see TODO)
    function test_evalMultivariate() external {
        uint256[10] memory expectedRes;
        expectedRes = [
            uint256(0),
            35,
            7490,
            1856260,
            561396360,
            204296864520,
            87625221860400,
            43459182957597120,
            24521778714010677120,
            15528655215813014311680
        ];
        for (uint256 numVariables = 1; numVariables < 11; numVariables++) {
            uint256 numCoeffs = 1 << numVariables;
            BN254.ScalarField[] memory coeffs = new BN254.ScalarField[](numCoeffs);
            BN254.ScalarField[] memory point = new BN254.ScalarField[](numVariables);
            for (uint256 j = 0; j < numCoeffs; j++) {
                coeffs[j] = BN254.ScalarField.wrap(j);
            }
            for (uint256 j = 0; j < numVariables; j++) {
                point[j] = BN254.ScalarField.wrap(j * 35);
            }

            BN254.ScalarField res = Coeffs.evalMultivariate(coeffs, point);
            assertEq(expectedRes[numVariables - 1], BN254.ScalarField.unwrap(res));
        }
    }
}