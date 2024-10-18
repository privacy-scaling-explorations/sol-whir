// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {BN254} from "solidity-bn254/BN254.sol";
import {console} from "forge-std/Test.sol";

library FiatShamir {
    /// @notice Derive `n` challenges using `scalars.length` provided values.
    function deriveChallengesFromScalars(BN254.ScalarField[] memory scalars, uint32 n)
        external
        pure
        returns (BN254.ScalarField[] memory)
    {
        require(scalars.length > 0);
        BN254.ScalarField[] memory challenges = new BN254.ScalarField[](n);
        bytes32 challengeBytes = keccak256(abi.encodePacked(scalars, uint32(0)));
        challenges[0] = BN254.ScalarField.wrap(uint256(challengeBytes));
        for (uint32 i = 1; i < n; i++) {
            challengeBytes = keccak256(abi.encodePacked(challengeBytes, i));
            challenges[i] = BN254.ScalarField.wrap(uint256(challengeBytes));
        }
        return challenges;
    }
}
