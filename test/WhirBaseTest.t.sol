// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {BN254} from "solidity-bn254/BN254.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// @notice Test contracts inherit from this Base contract, providing a few useful helper methods
// TODO: call arkworks with ffi instead of harcoding
contract WhirBaseTest is Test {
    function getFileName(
        uint256 numVariables,
        uint256 foldingFactor,
        uint256 numPoints,
        string memory soundnessType,
        uint256 powBits,
        uint256 startingLogInvRate,
        uint256 securityLevel,
        string memory foldType
    ) internal pure returns (string memory) {
        return string.concat(
            "proof_",
            Strings.toString(numVariables),
            "_",
            Strings.toString(foldingFactor),
            "_",
            Strings.toString(numPoints),
            "_",
            soundnessType,
            "_",
            Strings.toString(powBits),
            "_",
            Strings.toString(startingLogInvRate),
            "_",
            Strings.toString(securityLevel),
            "_",
            foldType,
            ".json"
        );
    }

    function resetBench(string memory path) internal returns (bool) {
        vm.removeFile(path);
        return false;
    }

    function writeLine(
        uint256 numVariables,
        uint256 foldingFactor,
        uint256 numPoints,
        string memory soundnessType,
        uint256 powBits,
        uint256 gasUsed,
        string memory path
    ) internal {
        string memory line = string.concat(
            Strings.toString(numVariables),
            ",",
            Strings.toString(foldingFactor),
            ",",
            Strings.toString(numPoints),
            ",",
            soundnessType,
            ",",
            Strings.toString(powBits),
            ",",
            "ProverHelps",
            ",",
            Strings.toString(gasUsed)
        );
        vm.writeLine(path, line);
    }

    function assertEqScalarField(BN254.ScalarField a, BN254.ScalarField b) public pure {
        assertEq(BN254.ScalarField.unwrap(a), BN254.ScalarField.unwrap(b));
    }

    function assertEqScalarFieldArray(BN254.ScalarField[] memory a, BN254.ScalarField[] memory b) public pure {
        for (uint256 i = 0; i < a.length; i++) {
            assertEqScalarField(a[i], b[i]);
        }
    }

    function assertEqUintScalarField(uint256 a, BN254.ScalarField b) public pure {
        assertEq(a, BN254.ScalarField.unwrap(BN254.add(b, BN254.ScalarField.wrap(0))));
    }

    function assertEqUint8Array(uint8[] memory a, uint8[] memory b) public pure {
        for (uint256 i = 0; i < a.length; i++) {
            assertEq(a[i], b[i]);
        }
    }
}
