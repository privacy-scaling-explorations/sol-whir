// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

library MerkleVerifier {
    uint256 public constant SIZE = 0x20;

    function hashLeaf(bytes32[] calldata leaves) internal pure returns (bytes32 res) {
        uint256 size = leaves.length * 32;
        assembly ("memory-safe") {
            let offset := leaves.offset
            let ptr := mload(0x40)
            mstore(0x40, add(ptr, size))
            calldatacopy(ptr, offset, size)
            res := keccak256(ptr, size)
        }
    }

    // adapted from: https://gist.github.com/Recmo/0dbbaa26c051bea517cd3a8f1de3560a
    function verify(
        bytes32 root,
        uint256 depth,
        uint256[] calldata indices,
        bytes32[][] calldata values,
        bytes32[] memory decommitments
    ) external pure {
        uint256 n = indices.length;
        uint256[] memory treeIndices = new uint256[](n + 1);
        bytes32[] memory hashes = new bytes32[](n + 1);
        uint256 head = 0;
        uint256 tail = 0;

        for (; tail < n; ++tail) {
            treeIndices[tail] = 2 ** depth + indices[n - tail - 1];
            hashes[tail] = hashLeaf(values[n - tail - 1]);
        }

        uint8 rootIsCorrect;

        assembly ("memory-safe") {
            // size of the `treeIndices` array + 1
            let s := add(mload(treeIndices), 1)

            // `head` keeps track of the current position in the array that we want to access
            // `head` is used to build the `headPtr`
            // `head` is in [0, ..., len(treeIndices) - 1], `headPtr` is multiples of 0x20
            // example: arr = [a, b, c]
            // if head = 0 -> add(arr, add(0x20, mul(0x20, head))) -> add(arr, add(0x20, 0))
            head := 0
            let headPtr := add(SIZE, mul(SIZE, head))
            let index := mload(add(treeIndices, headPtr))
            let hash := mload(add(hashes, headPtr))

            // we use the same logic for tail
            tail := tail
            let tailPtr := add(SIZE, mul(SIZE, tail))

            // for decommitments, the logic is different, since this is not a circular queue
            let decommPtr := SIZE

            // equiv. to while (index != 1)
            for {} gt(index, 1) {} {
                // order matters, update the ptr after the head value has been updated
                head := mod(add(head, 1), s)
                headPtr := add(SIZE, mul(SIZE, head))

                switch and(index, 1)
                case 0 {
                    // we have an even node index
                    let decomm := mload(add(decommitments, decommPtr)) // load the decommitment
                    mstore(0x00, hash) // current hash is left node
                    mstore(0x20, decomm) // decommitment is sibling
                    hash := keccak256(0x00, 0x40)

                    // decommitment pointer goes forward by one element
                    decommPtr := add(decommPtr, SIZE)
                }
                default {
                    // check if head equals tail and if next index is of a sibling node
                    let headNotEqTail := not(eq(head, tail)) // 1 when head != tail
                    let nextIndex := mload(add(treeIndices, headPtr))
                    let nextIndexIsSibling := eq(sub(index, 1), nextIndex) // 1 when index - 1 == nextIndex
                    switch and(headNotEqTail, nextIndexIsSibling)
                    case 1 {
                        let nextHash := mload(add(hashes, headPtr))
                        mstore(0x00, nextHash)
                        mstore(0x20, hash)
                        hash := keccak256(0x00, 0x40)

                        // order matters, update the ptr after the head value has been updated
                        head := mod(add(head, 1), s)
                        headPtr := add(SIZE, mul(SIZE, head))
                    }
                    default {
                        // last case, index is not even and next node is not a sibling node
                        // decomm is left node
                        let decomm := mload(add(decommitments, decommPtr)) // load the decommitment
                        mstore(0x00, decomm)
                        mstore(0x20, hash)
                        hash := keccak256(0x00, 0x40)

                        // decommitment pointer goes forward by one element
                        decommPtr := add(decommPtr, SIZE)
                    }
                }

                // update treeIndices and hashes arrays
                mstore(add(treeIndices, tailPtr), div(index, 2))
                mstore(add(hashes, tailPtr), hash)

                // update the tail pointer
                tail := mod(add(tail, 1), s)
                tailPtr := add(SIZE, mul(SIZE, tail))

                // load next (index, hash) pair
                index := mload(add(treeIndices, headPtr))
                hash := mload(add(hashes, headPtr))
            }

            rootIsCorrect := eq(root, hash)
        }

        require(rootIsCorrect == 1);
    }
}
