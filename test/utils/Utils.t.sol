// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {console} from "forge-std/Test.sol";
import {Utils} from "../../src/utils/Utils.sol";
import {WhirBaseTest} from "../WhirBaseTest.t.sol";
import {BN254} from "solidity-bn254/BN254.sol";
import {EVMFs, Arthur} from "../../src/fs/FiatShamir.sol";
import {LibSort} from "solady/src/utils/LibSort.sol";

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

    // @notice values from rust implem
    function test_toRangeSortAndDedup() external pure {
        bytes memory transcript = new bytes(2);
        bytes memory nextBytes;
        BN254.ScalarField[] memory squeezedScalars;
        transcript[0] = bytes1(uint8(2));
        transcript[1] = bytes1(uint8(4));
        Arthur memory arthur = EVMFs.newArthur();
        arthur.transcript = transcript;

        (arthur, nextBytes) = EVMFs.nextBytes(arthur, 2);
        (arthur, squeezedScalars) = EVMFs.squeezeScalars(arthur, uint32(5));
        uint256[] memory ranged = Utils.rangedArray(squeezedScalars, 15);
        LibSort.sort(ranged);
        LibSort.uniquifySorted(ranged);
        assertEq(ranged[0], 0);
        assertEq(ranged[1], 3);
        assertEq(ranged[2], 11);
        assertEq(ranged[3], 12);
    }
}
