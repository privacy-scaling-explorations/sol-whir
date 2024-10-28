// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {BN254} from "solidity-bn254/BN254.sol";

library Utils {
    uint256 public constant R_MOD = 21888242871839275222246405745257275088548364400416034343698204186575808495617;

    function requireEqualScalars(BN254.ScalarField a, BN254.ScalarField b) external pure {
        require(BN254.ScalarField.unwrap(a) == BN254.ScalarField.unwrap(b));
    }

    function expandRandomness(BN254.ScalarField base, uint256 len) external pure returns (BN254.ScalarField[] memory) {
        BN254.ScalarField[] memory res = new BN254.ScalarField[](len);
        assembly {
            let resPtr := add(res, 0x20)
            let acc := 1
            for { let i := 0 } lt(i, len) { i := add(i, 1) } {
                mstore(resPtr, acc)
                acc := mulmod(acc, base, R_MOD)
                resPtr := add(resPtr, 0x20)
            }
        }
        return res;
    }
}
