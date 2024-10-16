// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {MerkleProof} from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";

// TODO integrate into Verifier.sol instead
contract MerkleVerifier {
    function verify(bytes32[] memory proof, bytes32 root, bytes32[] memory leaves, bool[] memory proofFlags)
        public
        pure
        returns (bool)
    {
        return MerkleProof.multiProofVerify(proof, proofFlags, root, leaves);
    }
}
