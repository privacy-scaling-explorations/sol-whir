// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console, Vm} from "forge-std/Test.sol";
import {BN254} from "solidity-bn254/BN254.sol";
import {Utils} from "src/utils/Utils.sol";
import {StatefulSponge} from "lib-keccak/StatefulSponge.sol";

contract FiatShamirTest is Test {
    StatefulSponge keccakSponge;

    function setUp() public {
        keccakSponge = new StatefulSponge();
    }

    function test_absorbSingleScalar() public {
        // see nimue/ark/common.rs for how bytes are absorbed by the hash function
        // they are absorbed one by one
        // data is 32 bytes here, this corresponds to one field element
        bytes memory oneByte = new bytes(32);
        vm.startSnapshotGas("absorb");
        keccakSponge.absorb(oneByte);
        uint256 gasUsedAbsorb = vm.stopSnapshotGas("absorb");
        assertEq(gasUsedAbsorb, 345401);

        vm.startSnapshotGas("squeeze");
        keccakSponge.squeeze();
        uint256 gasUsedSqueeze = vm.stopSnapshotGas("squeeze");
        assertEq(gasUsedSqueeze, 11683);
    }

    function test_absorbPolynomial() public {}
}
