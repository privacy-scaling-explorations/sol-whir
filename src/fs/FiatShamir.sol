// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {BN254} from "solidity-bn254/BN254.sol";

/// @notice Provides fs utilities
/// @dev API slightly differs from what has been implemented on the whir side
library EVMFs {
    uint256 public constant R_MOD = 21888242871839275222246405745257275088548364400416034343698204186575808495617;

    function checkPow(bytes calldata transcript, uint256 cur, bytes32 state, uint256 powBits)
        external
        pure
        returns (uint256, bytes32)
    {
        bytes32 challenge = hash(state);
        bytes8 nonce = bytes8(transcript[cur:cur + 8]);
        state = hash8Bytes(nonce);
        bytes32 res = hashChallengeAndNonce(challenge, nonce);
        cur += 8;
        require(uint256(res) < uint256(1) << (256 - powBits));
        return (cur, state);
    }

    function hashChallengeAndNonce(bytes32 challenge, bytes8 nonce) private pure returns (bytes32) {
        bytes32 res;
        assembly ("memory-safe") {
            mstore(0x00, challenge)
            mstore(0x20, nonce)
            res := keccak256(0x00, 0x28)
        }
        return res;
    }

    function hash8Bytes(bytes8 value) private pure returns (bytes32) {
        bytes32 res;
        assembly ("memory-safe") {
            mstore(0x00, value)
            res := keccak256(0x00, 0x8)
        }
        return res;
    }

    function hash(bytes32 value) private pure returns (bytes32) {
        bytes32 res;
        assembly ("memory-safe") {
            mstore(0x00, value)
            res := keccak256(0x00, 0x20)
        }
        return res;
    }

    function squeezeScalars1(bytes32 state) external pure returns (BN254.ScalarField) {
        return BN254.ScalarField.wrap(uint256(hash(state)));
    }

    // @dev used when generating stir challenges, we want values in the range [0, max]
    // those values are from the scalar field
    function squeezeRangedUints(bytes32 state, uint256 n, uint256 max)
        external
        pure
        returns (uint256[] memory challenges)
    {
        assembly {
            // initialize challenges array
            challenges := mload(0x40)
            mstore(challenges, n)
            let challengesStart := add(challenges, 0x20)

            // the first challenge will be computed from the state
            let challenge := state

            for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                mstore(0x00, challenge)
                challenge := keccak256(0x00, 0x20)
                let toStore := modChallenge(challenge, max)
                mstore(add(challengesStart, mul(0x20, i)), toStore)
            }

            // update free mem ptr
            mstore(0x40, add(challengesStart, mul(0x20, n)))

            function modChallenge(chall, m) -> value {
                let modR := mod(chall, R_MOD)
                value := mod(modR, m)
            }
        }
    }

    function squeezeScalars(bytes32 state, uint32 n) external pure returns (BN254.ScalarField[] memory) {
        BN254.ScalarField[] memory challenges = new BN254.ScalarField[](n);
        bytes32 challengeBytes = hash(state);
        challenges[0] = BN254.ScalarField.wrap(uint256(challengeBytes));
        for (uint32 i = 1; i < n; i++) {
            challengeBytes = hash(challengeBytes);
            challenges[i] = BN254.ScalarField.wrap(uint256(challengeBytes));
        }
        return (challenges);
    }

    function bytesToScalar(bytes calldata scalar) private pure returns (BN254.ScalarField) {
        return BN254.ScalarField.wrap(uint256(bytes32(scalar)));
    }

    // @notice Outputs next transcript bytes
    function nextBytes32(bytes calldata transcript, uint256 cur) external pure returns (uint256, bytes32, bytes32) {
        return (cur + 32, hash(bytes32(transcript[cur:cur + 32])), bytes32(transcript[cur:cur + 32]));
    }

    // @notice Outputs next transcript bytes
    function nextBytes(bytes calldata transcript, uint256 cur, uint128 n)
        external
        pure
        returns (uint256, bytes32, bytes memory)
    {
        return (cur + n, keccak256(transcript[cur:cur + n]), transcript[cur:cur + n]);
    }

    // @notice BN254.ScalarField elements are serialized into 32 bytes array
    function nextScalars1(bytes calldata transcript, uint256 cur)
        external
        pure
        returns (uint256, bytes32, BN254.ScalarField[] memory)
    {
        BN254.ScalarField[] memory res = new BN254.ScalarField[](1);
        res[0] = bytesToScalar(transcript[cur:cur + 32]);

        return (cur + 32, hash(bytes32(transcript[cur:cur + 32])), res);
    }

    // @notice BN254.ScalarField elements are serialized into 32 bytes array
    function nextScalars3(bytes memory transcript, uint256 cur)
        external
        pure
        returns (uint256 curNew, bytes32 state, BN254.ScalarField val1, BN254.ScalarField val2, BN254.ScalarField val3)
    {
        assembly {
            let bytesPtr := add(transcript, 0x20)
            bytesPtr := add(bytesPtr, cur)
            curNew := add(cur, 96)
            state := keccak256(bytesPtr, 0x60)
            val1 := mod(mload(bytesPtr), R_MOD)
            val2 := mod(mload(add(bytesPtr, 0x20)), R_MOD)
            val3 := mod(mload(add(bytesPtr, 0x40)), R_MOD)
        }
    }

    function nextScalars(bytes memory transcript, uint256 cur, uint128 n)
        external
        pure
        returns (uint256 newCur, bytes32 state, BN254.ScalarField[] memory scalars)
    {
        scalars = new BN254.ScalarField[](n);
        assembly {
            // pointer to the scalar array
            let scalarsPtr := add(scalars, 0x20)
            // pointer to transcript + skip cur bytes
            let transcriptPtr := add(add(transcript, 0x20), cur)
            for { let i := 0 } lt(i, n) { i := add(i, 1) } {
                // store the current scalar in the scalarsPtr position
                // take scalar mod R_MOD
                mstore(scalarsPtr, mod(mload(transcriptPtr), R_MOD))
                // update scalars and transcript pointers
                scalarsPtr := add(scalarsPtr, 0x20)
                transcriptPtr := add(transcriptPtr, 0x20)
            }
            newCur := add(cur, mul(n, 32))
            state := keccak256(add(add(transcript, 0x20), cur), mul(n, 0x20))
        }
    }
}
