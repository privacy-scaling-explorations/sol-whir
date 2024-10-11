// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Utils} from "../../src/utils/Utils.sol";
import {WhirBaseTest} from "../WhirBaseTest.t.sol";

contract UtilsTest is WhirBaseTest {
    function test_baseDecomposition() external pure {
        uint8[] memory res1 = Utils.baseDecomposition(100, 3, 5);
        uint8[] memory expectedRes1 = new uint8[](5);
        expectedRes1[0] = 1;
        expectedRes1[1] = 0;
        expectedRes1[2] = 2;
        expectedRes1[3] = 0;
        expectedRes1[4] = 1;

        assertEqUint8Array(res1, expectedRes1);

        uint8[] memory res2 = Utils.baseDecomposition(42, 3, 4);
        uint8[] memory expectedRes2 = new uint8[](4);
        expectedRes2[0] = 1;
        expectedRes2[1] = 1;
        expectedRes2[2] = 2;
        expectedRes2[3] = 0;

        assertEqUint8Array(res2, expectedRes2);
    }
}
