// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {MerkleProof} from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";

// TODO preimages and root will be provided separately
// They are included for testing convenience
struct MultiProof {
    uint256[][] preimages;
    bytes32[] proof;
    bool[] proofFlags;
    bytes32 root;
}

contract MerkleVerifier {
    function verify(bytes32[] memory proof, bytes32 root, uint256[][] memory leaves, bool[] memory proofFlags)
        public
        pure
        returns (bool)
    {
        bytes32[] memory leafHashes = new bytes32[](leaves.length);
        for (uint256 i = 0; i < leaves.length; i++) {
            leafHashes[i] = keccak256(abi.encodePacked(leaves[i]));
        }

        return MerkleProof.multiProofVerify(proof, proofFlags, root, leafHashes);
    }
}
