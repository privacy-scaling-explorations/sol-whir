// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Verifier} from "../src/Whir.sol";

import {JSONWhirProof, JSONUtils} from "../src/utils/WhirJson.sol";
import {WhirProof, Statement, WhirConfig} from "../src/WhirStructs.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {VmSafe} from "forge-std/Vm.sol";

contract WhirContract {
    bool result;

    constructor() {
        result = false;
    }

    function callVerify(
        WhirConfig calldata config,
        Statement calldata statement,
        WhirProof calldata whirProof,
        bytes calldata transcript
    ) external {
        require(Verifier.verify(config, statement, whirProof, transcript));
        result = true;
    }
}

contract VerifyScript is Script {
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

    function resetBench(string memory path) private returns (bool) {
        vm.removeFile(path);
        return false;
    }

    function getFileName(
        uint256 index,
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
            Strings.toString(index),
            "_",
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

    function writeLine(string memory benchPath, string memory path, uint256 gasLimit, int64 gasRefund, uint256 gasUsed)
        private
    {
        string memory line = string.concat(
            path,
            ",",
            Strings.toString(gasLimit),
            ",",
            Strings.toStringSigned(gasRefund),
            ",",
            Strings.toString(gasUsed)
        );
        vm.writeLine(benchPath, line);
    }

    WhirContract whirContract;
    uint256 deployerPrivateKey;
    string projectRoot;

    function setUp() public {
        deployerPrivateKey = vm.envBool("LOCAL") ? vm.envUint("LOCAL_PRIVATE_KEY") : vm.envUint("SEPOLIA_PRIVATE_KEY");
        projectRoot = vm.projectRoot();

        vm.startBroadcast(deployerPrivateKey);
        whirContract = new WhirContract();
        vm.stopBroadcast();
    }

    function run() external {
        WhirConfig memory config;
        Statement memory statement;
        WhirProof memory whirProof;
        bytes memory transcript;

        uint256 nVariable = 16;
        uint256 securityLevel = 80;
        uint256 foldingFactor = 4;
        uint256 startingLogInvRate = 6;
        uint256 powBit = 30;

        vm.startBroadcast(deployerPrivateKey);
        string memory dirPath = "./test/data/whir/";
        string memory fname = getFileName(
            nVariable, foldingFactor, 1, "ConjectureList", powBit, startingLogInvRate, securityLevel, "ProverHelps"
        );
        string memory path = string.concat(dirPath, "/", fname);
        (config, statement, whirProof, transcript) = getProofElements(path);
        whirContract.callVerify(config, statement, whirProof, transcript);
        vm.stopBroadcast();
    }
}
