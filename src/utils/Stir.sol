// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {BN254} from "solidity-bn254/BN254.sol";
import {EVMFs} from "../fs/FiatShamir.sol";

library StirUtils {
    function getStirChallengePoints(uint256[] calldata stirChallengeIndexes, BN254.ScalarField expDomainGen)
        external
        pure
        returns (BN254.ScalarField[] memory)
    {
        uint256 length = stirChallengeIndexes.length;
        uint256 base = BN254.ScalarField.unwrap(expDomainGen);
        BN254.ScalarField[] memory stirChallengePoints = new BN254.ScalarField[](length);
        for (uint256 i = 0; i < length;) {
            stirChallengePoints[i] = BN254.ScalarField.wrap(BN254.powSmall(base, stirChallengeIndexes[i], BN254.R_MOD));
            unchecked {
                ++i;
            }
        }
        return stirChallengePoints;
    }
}
