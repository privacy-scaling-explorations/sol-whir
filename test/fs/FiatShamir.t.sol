// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {BN254} from "solidity-bn254/BN254.sol";

import {console} from "forge-std/Test.sol";
import {WhirBaseTest} from "../WhirBaseTest.t.sol";
import {EVMFs, Arthur} from "../../src/fs/FiatShamir.sol";

contract EVMFsTest is WhirBaseTest {
    // @notice test values taken from rust implem
    function test_arthur() external pure {
        Arthur memory arthur = EVMFs.newArthur();
        bytes memory transcript = new bytes(160);
        for (uint8 i = 0; i < 160; i++) {
            transcript[i] = bytes1(i);
        }
        arthur.transcript = transcript;
        BN254.ScalarField[] memory scalars = new BN254.ScalarField[](2);
        bytes memory b = new bytes(32);
        bytes32[] memory bytesArray = new bytes32[](2);

        (arthur, scalars) = EVMFs.nextScalars(arthur, 2);
        assertEqUintScalarField(1780731860627700044960722568376592200742329637303199754547598369979440671, scalars[0]);
        assertEqUintScalarField(
            14532552714582660066924456880521368950258152170031413196862950297402215317055, scalars[1]
        );
        assertEq(arthur.cur, 64);
        (arthur, scalars) = EVMFs.squeezeScalars(arthur, 2);
        assertEqUintScalarField(
            12683060701355308782706700515672074170454102507116826504056080700491237103607, scalars[0]
        );
        assertEqUintScalarField(
            13839230134794589166250157080361894918759939301567037118679620098290800826094, scalars[1]
        );
        (arthur, scalars) = EVMFs.nextScalars(arthur, 1);
        assertEq(arthur.cur, 96);
        assertEqUintScalarField(
            7175081825465417211557547293217086219767197610009488850273148809858642697822, scalars[0]
        );
        (arthur, scalars) = EVMFs.squeezeScalars(arthur, 2);
        assertEqUintScalarField(
            1771673146623460978843697473455519743229658119711270841913389261238928066891, scalars[0]
        );
        assertEqUintScalarField(
            13414504394749035439026830226758505404562455097332190602756292500867339601090, scalars[1]
        );

        (arthur, b) = EVMFs.nextBytes(arthur, 32);
        assertEq(arthur.cur, 128);
        assertEq(b, hex"7f7e7d7c7b7a797877767574737271706f6e6d6c6b6a69686766656463626160");
        (arthur, scalars) = EVMFs.squeezeScalars(arthur, 1);
        assertEqUintScalarField(40276879530910984420319267942312546383818757582133881715188209916716224991, scalars[0]);
        (arthur, b) = EVMFs.nextBytes(arthur, 32);
        assertEq(b, hex"9f9e9d9c9b9a999897969594939291908f8e8d8c8b8a89888786858483828180");
        assertEq(arthur.cur, 160);
        (arthur, bytesArray) = EVMFs.squeezeBytes(arthur, 2);
        assertEq(bytesArray[0], hex"739dee39dfe0e4116cf2fa867fcc4d4f985eb00353a7f5d164c8933d0f53c840");
        assertEq(bytesArray[1], hex"2c49be39f1c3b49c2aa0f911b1c9a494d68124585d2cc86ce890f2bc79628706");
    }
}
