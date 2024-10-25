// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {BN254} from "solidity-bn254/BN254.sol";

struct Arthur {
    bytes transcript;
    bytes state;
    uint256 cur; // pointer to current transcript bytes
}

/// @notice Provides fs utilities, Arthur only
/// @dev API slightly differs from what has been implemented on the whir side
library EVMFs {
    function newArthur() external pure returns (Arthur memory) {
        Arthur memory arthur;
        return arthur;
    }

    function squeezeScalars(Arthur memory arthur, uint32 n)
        external
        pure
        returns (Arthur memory, BN254.ScalarField[] memory)
    {
        BN254.ScalarField[] memory challenges = new BN254.ScalarField[](n);
        bytes32 challengeBytes = keccak256(abi.encodePacked(arthur.state, uint32(0)));
        challenges[0] = BN254.ScalarField.wrap(uint256(challengeBytes));
        for (uint32 i = 1; i < n; i++) {
            challengeBytes = keccak256(abi.encodePacked(challengeBytes, uint32(i)));
            challenges[i] = BN254.ScalarField.wrap(uint256(challengeBytes));
        }
        delete arthur.state;
        return (arthur, challenges);
    }

    function squeezeBytes(Arthur memory arthur, uint32 n) external pure returns (Arthur memory, bytes32[] memory) {
        bytes32[] memory challenges = new bytes32[](n);
        bytes32 challengeBytes = keccak256(abi.encodePacked(arthur.state, uint32(0)));
        challenges[0] = challengeBytes;
        for (uint32 i = 1; i < n; i++) {
            challengeBytes = keccak256(abi.encodePacked(challengeBytes, uint32(i)));
            challenges[i] = challengeBytes;
        }
        delete arthur.state;
        return (arthur, challenges);
    }

    function bytesToScalar(bytes memory scalar) private pure returns (BN254.ScalarField) {
        return BN254.ScalarField.wrap(uint256(bytes32(scalar)));
    }

    function nextBytes(Arthur memory arthur, uint128 n) external pure returns (Arthur memory, bytes memory) {
        arthur.state = new bytes(n);
        bytes memory res = new bytes(n);
        for (uint128 i = 0; i < n; i++) {
            arthur.state[i] = arthur.transcript[arthur.cur + i];
            res[n - 1 - i] = arthur.transcript[arthur.cur + i];
        }
        arthur.cur += n; // transcript pointer goes forward
        return (arthur, res);
    }

    // @notice BN254.ScalarField elements are serialized into 32 bytes array
    function nextScalars(Arthur memory arthur, uint128 n)
        external
        pure
        returns (Arthur memory, BN254.ScalarField[] memory)
    {
        BN254.ScalarField[] memory scalars = new BN254.ScalarField[](n);
        arthur.state = new bytes(n * 32);
        for (uint128 i = 0; i < n * 32; i += 32) {
            bytes memory scalar = new bytes(32);
            for (uint128 j = 0; j < 32; j++) {
                uint256 idx = i + j;
                arthur.state[idx] = arthur.transcript[arthur.cur + idx];
                scalar[j] = arthur.transcript[arthur.cur + idx];
            }
            scalars[i / 32] = bytesToScalar(scalar);
        }
        arthur.cur += n * 32; // transcript pointer goes forward
        return (arthur, scalars);
    }
}
