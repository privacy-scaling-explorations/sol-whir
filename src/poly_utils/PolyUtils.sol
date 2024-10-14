// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {BN254} from "solidity-bn254/BN254.sol";
import {Utils} from "../utils/Utils.sol";

struct MultilinearPoint {
    BN254.ScalarField[] point;
}

library PolyUtils {
    function newMultilinearPoint(BN254.ScalarField[] memory point) public pure returns (MultilinearPoint memory) {
        return MultilinearPoint(point);
    }

    function expandFromUnivariate(BN254.ScalarField point, uint256 numVariables)
        external
        pure
        returns (MultilinearPoint memory)
    {
        BN254.ScalarField[] memory res = new BN254.ScalarField[](numVariables);
        BN254.ScalarField cur = point;
        for (uint256 i = 0; i < numVariables; i++) {
            res[numVariables - 1 - i] = cur;
            cur = BN254.mul(cur, cur);
        }
        return MultilinearPoint(res);
    }

    function eqPolyOutside(MultilinearPoint memory coords, MultilinearPoint memory point)
        external
        pure
        returns (BN254.ScalarField)
    {
        require(coords.point.length == point.point.length, "eqPolyOutside: number of variables should be the same");
        BN254.ScalarField acc = BN254.ScalarField.wrap(1);
        for (uint256 i = 0; i < coords.point.length; i++) {
            (BN254.ScalarField l, BN254.ScalarField r) = (coords.point[i], point.point[i]);
            BN254.ScalarField a = BN254.mul(l, r);
            BN254.ScalarField b = BN254.add(BN254.ScalarField.wrap(1), BN254.negate(l));
            BN254.ScalarField c = BN254.add(BN254.ScalarField.wrap(1), BN254.negate(r));
            acc = BN254.mul(acc, BN254.add(a, BN254.mul(b, c)));
        }
        return acc;
    }

    function eqPoly3(MultilinearPoint memory coords, uint256 point) public pure returns (BN254.ScalarField) {
        BN254.ScalarField acc = BN254.ScalarField.wrap(1);

        for (uint256 i = 0; i < coords.point.length; i++) {
            uint256 b = point % 3;
            BN254.ScalarField val = coords.point[coords.point.length - 1 - i];
            if (b == 0) {
                BN254.ScalarField x = BN254.add(val, Utils.BN254_MINUS_ONE);
                BN254.ScalarField y = BN254.add(val, BN254.negate(Utils.BN254_TWO));
                BN254.ScalarField z = BN254.mul(x, y);
                acc = BN254.mul(acc, BN254.mul(z, Utils.BN254_TWO_INV));
            } else if (b == 1) {
                BN254.ScalarField x = BN254.add(val, BN254.negate(Utils.BN254_TWO));
                BN254.ScalarField y = BN254.mul(x, Utils.BN254_MINUS_ONE);
                BN254.ScalarField z = BN254.mul(val, y);
                acc = BN254.mul(acc, z);
            } else {
                BN254.ScalarField x = BN254.add(val, Utils.BN254_MINUS_ONE);
                BN254.ScalarField y = BN254.mul(x, Utils.BN254_TWO_INV);
                BN254.ScalarField z = BN254.mul(val, y);
                acc = BN254.mul(acc, z);
            }

            point /= 3;
        }
        return acc;
    }
}
