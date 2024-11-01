// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {console, Vm} from "forge-std/Test.sol";
import {WhirBaseTest} from "./WhirBaseTest.t.sol";
import {Verifier, WhirConfig, Statement, WhirProof} from "../src/Verifier.sol";
import {JSONWhirProof, JSONUtils} from "../src/utils/WhirJson.sol";
import {Arthur, EVMFs} from "../src/fs/FiatShamir.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract VerifierTest is WhirBaseTest {
    function getFileName(
        uint256 numVariables,
        uint256 foldingFactor,
        uint256 numPoints,
        string memory soundnessType,
        uint256 powBits,
        string memory foldType
    ) internal pure returns (string memory) {
        return string.concat(
            "proof",
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
            foldType,
            ".json"
        );
    }

    function resetBench(string memory path) private returns (bool) {
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
    ) private {
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

    function test_benchVerifySingle() external {
        string memory projectRoot = vm.projectRoot();
        string memory benchPath = string.concat(projectRoot, "/test/data/bench/bench.csv");
        vm.exists(benchPath) ? resetBench(benchPath) : true;
        vm.writeLine(benchPath, "numVariables,foldingFactor,numPoints,soundnessType,powBits,foldType,gasUsed");
               string memory proofPath = string.concat(
                    projectRoot,
                    "/test/data/whir/",
                    getFileName(
                        20,
                        4,
                        1,
                        "ConjectureList",
                        0,
                        "ProverHelps"
                    )
                );

                string memory proofJson = vm.readFile(proofPath);
                bytes memory parsed = vm.parseJson(proofJson);
                JSONWhirProof memory jsonProof = abi.decode(parsed, (JSONWhirProof));

                WhirConfig memory config = JSONUtils.jsonWhirConfigToWhirConfig(jsonProof.config);
                Statement memory statement = JSONUtils.jsonStatementToStatement(jsonProof.statement);
                WhirProof memory whirProof = JSONUtils.jsonWhirProofToWhirProof(jsonProof);
                Arthur memory arthur = EVMFs.newArthur();
                arthur.transcript = jsonProof.arthur.transcript;
                vm.startSnapshotGas("verifSnapshot");
                bool res = Verifier.verify(config, statement, whirProof, arthur);
                uint256 gasUsed = vm.stopSnapshotGas("verifSnapshot");
                assertTrue(res, "Could not verify proof");
                writeLine(
                    20,
                    4,
                    1,
                    "ConjectureList",
                    0,
                    gasUsed,
                    benchPath
                );
    }

    function test_benchVerify() external {
        string[3] memory soundnessTypes = ["ConjectureList", "ProvableList", "UniqueDecoding"];
        uint256[1] memory powBits = [uint256(0)];
        string memory projectRoot = vm.projectRoot();
        string memory benchPath = string.concat(projectRoot, "/test/data/bench/bench.csv");
        vm.exists(benchPath) ? resetBench(benchPath) : true;
        vm.writeLine(benchPath, "numVariables,foldingFactor,numPoints,soundnessType,powBits,foldType,gasUsed");
        for (uint256 foldingFactor = 1; foldingFactor <= 4; foldingFactor++) {
            for (uint256 numVariables = foldingFactor; numVariables <= 3 * foldingFactor; numVariables++) {
                for (uint256 numPoints = 1; numPoints <= 3; numPoints++) {
                    for (uint256 soundnessTypeIdx = 0; soundnessTypeIdx < soundnessTypes.length; soundnessTypeIdx++) {
                        for (uint256 powBitsIdx = 0; powBitsIdx < powBits.length; powBitsIdx++) {
                            string memory proofPath = string.concat(
                                projectRoot,
                                "/test/data/whir/",
                                getFileName(
                                    numVariables,
                                    foldingFactor,
                                    numPoints,
                                    soundnessTypes[soundnessTypeIdx],
                                    powBits[powBitsIdx],
                                    "ProverHelps"
                                )
                            );

                            string memory proofJson = vm.readFile(proofPath);
                            bytes memory parsed = vm.parseJson(proofJson);
                            JSONWhirProof memory jsonProof = abi.decode(parsed, (JSONWhirProof));

                            WhirConfig memory config = JSONUtils.jsonWhirConfigToWhirConfig(jsonProof.config);
                            Statement memory statement = JSONUtils.jsonStatementToStatement(jsonProof.statement);
                            WhirProof memory whirProof = JSONUtils.jsonWhirProofToWhirProof(jsonProof);
                            Arthur memory arthur = EVMFs.newArthur();
                            arthur.transcript = jsonProof.arthur.transcript;
                            vm.startSnapshotGas("verifSnapshot");
                            bool res = Verifier.verify(config, statement, whirProof, arthur);
                            uint256 gasUsed = vm.stopSnapshotGas("verifSnapshot");
                            assertTrue(res, "Could not verify proof");
                            writeLine(
                                numVariables,
                                foldingFactor,
                                numPoints,
                                soundnessTypes[soundnessTypeIdx],
                                powBits[powBitsIdx],
                                gasUsed,
                                benchPath
                            );
                        }
                    }
                }
            }
        }
    }
}
