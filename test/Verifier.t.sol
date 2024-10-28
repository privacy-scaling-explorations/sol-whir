// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Verifier} from "../src/Whir.sol";
import {WhirBaseTest} from "./WhirBaseTest.t.sol";
import {JSONWhirProof, JSONUtils} from "../src/utils/WhirJson.sol";
import {WhirProof, Statement, WhirConfig} from "../src/WhirStructs.sol";
import {BN254} from "solidity-bn254/BN254.sol";
import {console} from "forge-std/Test.sol";
import {VerifierUtils} from "../src/verifier_utils/VerifierUtils.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {VmSafe} from "forge-std/Vm.sol";

contract WhirVerifierTest is WhirBaseTest {
    function verify(
        WhirConfig calldata config,
        Statement calldata statement,
        WhirProof calldata whirProof,
        bytes calldata transcript
    ) external returns (uint256) {
        vm.startSnapshotGas("verif", "verif");
        require(Verifier.verify(config, statement, whirProof, transcript));
        return vm.stopSnapshotGas("verif", "verif");
    }
}

contract VerifierTest is WhirBaseTest {
    WhirVerifierTest verifier;

    function setUp() public {
        verifier = new WhirVerifierTest();
    }

    function getProofElements(string memory proofPath)
        internal
        view
        returns (WhirConfig memory, Statement memory, WhirProof memory, bytes memory)
    {
        string memory proofJson;
        bytes memory parsed;
        proofJson = vm.readFile(proofPath);
        parsed = vm.parseJson(proofJson);
        JSONWhirProof memory jsonProof = abi.decode(parsed, (JSONWhirProof));
        WhirConfig memory config = JSONUtils.jsonWhirConfigToWhirConfig(jsonProof.config);
        Statement memory statement = JSONUtils.jsonStatementToStatement(jsonProof.statement);
        WhirProof memory whirProof = JSONUtils.jsonWhirProofToWhirProof(jsonProof);
        bytes memory transcript = jsonProof.arthur.transcript;
        return (config, statement, whirProof, transcript);
    }

    function test_verify() external {
        string memory projectRoot;
        WhirConfig memory config;
        Statement memory statement;
        WhirProof memory whirProof;
        bytes memory transcript;
        projectRoot = vm.projectRoot();

        uint256 securityLevel = uint256(80);
        uint256 foldingFactor = uint256(4);
        uint256 startingLogInvRate = uint256(6);
        uint256 nVariable = uint256(16);
        uint256 powBit = uint256(30);

        string memory dirPath = string.concat("./test/data/whir/");
        string memory fname = getFileName(
            nVariable, foldingFactor, 1, "ConjectureList", powBit, startingLogInvRate, securityLevel, "ProverHelps"
        );
        string memory path = string.concat(dirPath, "/", fname);
        (config, statement, whirProof, transcript) = getProofElements(path);
        uint256 gasUsed = verifier.verify(config, statement, whirProof, transcript);
    }
}
