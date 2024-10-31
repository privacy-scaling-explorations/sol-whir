// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {WhirConfig, RoundParameters, WhirProof, MerkleProof, Statement} from "../Verifier.sol";
import {BN254} from "solidity-bn254/BN254.sol";
import {MultilinearPoint} from "../poly_utils/PolyUtils.sol";

// @dev structs below are used for intermediary conversions,
// done when loading a whir proof serialized to a json file
struct JSONMerkleProof {
    bytes32[] proof;
    bool[] proofFlags;
}

struct JSONStatement {
    bytes32[] evaluations;
    bytes32[][] points;
}

struct JSONTranscript {
    bytes transcript;
}

struct JSONWhirProof {
    uint256[][][] answers;
    JSONTranscript arthur;
    JSONWhirConfig config;
    JSONMerkleProof[] merkleProofs;
    JSONStatement statement;
}

struct JSONRoundParameters {
    uint256 foldingPowBits;
    uint256 logInvRate;
    uint32 numQueries;
    uint32 oodSamples;
    uint256 powBits;
}

struct JSONWhirConfig {
    uint32 commitmentOodSamples;
    bytes32 domainGen;
    bytes32 domainGenInv;
    uint256 domainSize;
    bytes32 expDomainGen;
    uint256 finalFoldingPowBits;
    uint256 finalLogInvRate;
    uint256 finalPowBits;
    uint32 finalQueries;
    uint128 finalSumcheckRounds;
    uint256 foldingFactor;
    uint256 maxPow;
    uint256 numVariables;
    JSONRoundParameters[] roundParameters;
    uint256 securityLevel;
    uint256 startingFoldingPowBits;
    uint256 startingLogInvRate;
}

library JSONUtils {
    function jsonStatementToStatement(JSONStatement memory jsonStatement) external pure returns (Statement memory) {
        Statement memory statement;
        statement.evaluations = new BN254.ScalarField[](jsonStatement.evaluations.length);
        statement.points = new MultilinearPoint[](jsonStatement.points.length);
        for (uint256 i = 0; i < jsonStatement.evaluations.length; i++) {
            statement.evaluations[i] = BN254.ScalarField.wrap(uint256(jsonStatement.evaluations[i]));
        }
        for (uint256 i = 0; i < jsonStatement.points.length; i++) {
            MultilinearPoint memory point;
            point.point = new BN254.ScalarField[](jsonStatement.points[i].length);
            for (uint256 j = 0; j < jsonStatement.points[i].length; j++) {
                point.point[j] = BN254.ScalarField.wrap(uint256(jsonStatement.points[i][j]));
            }
            statement.points[i] = point;
        }
        return statement;
    }

    function jsonWhirProofToWhirProof(JSONWhirProof memory jsonWhirProof) external pure returns (WhirProof memory) {
        WhirProof memory proof;
        proof.merkleProofs = new MerkleProof[](jsonWhirProof.merkleProofs.length);
        for (uint256 i = 0; i < jsonWhirProof.merkleProofs.length; i++) {
            MerkleProof memory mp;
            mp.proofFlags = jsonWhirProof.merkleProofs[i].proofFlags;
            mp.proof = jsonWhirProof.merkleProofs[i].proof;
            proof.merkleProofs[i] = mp;
        }
        proof.answers = jsonWhirProof.answers;
        return proof;
    }

    function jsonRoundParametersToRoundParameters(JSONRoundParameters memory jsonRoundParameters)
        private
        pure
        returns (RoundParameters memory)
    {
        RoundParameters memory roundParameters;
        roundParameters.foldingPowBits = jsonRoundParameters.foldingPowBits;
        roundParameters.logInvRate = jsonRoundParameters.logInvRate;
        roundParameters.numQueries = jsonRoundParameters.numQueries;
        roundParameters.oodSamples = jsonRoundParameters.oodSamples;
        roundParameters.powBits = jsonRoundParameters.powBits;
        return roundParameters;
    }

    function jsonWhirConfigToWhirConfig(JSONWhirConfig memory jsonWhirConfig)
        external
        pure
        returns (WhirConfig memory)
    {
        RoundParameters[] memory roundParameters = new RoundParameters[](jsonWhirConfig.roundParameters.length);

        for (uint256 i = 0; i < jsonWhirConfig.roundParameters.length; i++) {
            roundParameters[i] = jsonRoundParametersToRoundParameters(jsonWhirConfig.roundParameters[i]);
        }

        WhirConfig memory whirConfig;
        whirConfig.commitmentOodSamples = jsonWhirConfig.commitmentOodSamples;
        whirConfig.domainGen = BN254.ScalarField.wrap(uint256(jsonWhirConfig.domainGen));
        whirConfig.domainGenInv = BN254.ScalarField.wrap(uint256(jsonWhirConfig.domainGenInv));
        whirConfig.expDomainGen = BN254.ScalarField.wrap(uint256(jsonWhirConfig.expDomainGen));
        whirConfig.domainSize = jsonWhirConfig.domainSize;
        whirConfig.finalFoldingPowBits = jsonWhirConfig.finalFoldingPowBits;
        whirConfig.finalLogInvRate = jsonWhirConfig.finalLogInvRate;
        whirConfig.finalPowBits = jsonWhirConfig.finalPowBits;
        whirConfig.finalQueries = jsonWhirConfig.finalQueries;
        whirConfig.finalSumcheckRounds = jsonWhirConfig.finalSumcheckRounds;
        whirConfig.foldingFactor = jsonWhirConfig.foldingFactor;
        whirConfig.maxPow = jsonWhirConfig.maxPow;
        whirConfig.numVariables = jsonWhirConfig.numVariables;
        whirConfig.roundParameters = roundParameters;
        whirConfig.securityLevel = jsonWhirConfig.securityLevel;
        whirConfig.startingFoldingPowBits = jsonWhirConfig.startingFoldingPowBits;
        whirConfig.startingLogInvRate = jsonWhirConfig.startingLogInvRate;

        return whirConfig;
    }
}
