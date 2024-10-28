// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {BN254} from "solidity-bn254/BN254.sol";
import {Multivariate} from "./poly_utils/Coeffs.sol";
import {SumcheckRound} from "./sumcheck/Proof.sol";

struct Statement {
    BN254.ScalarField[][] points;
    BN254.ScalarField[] evaluations;
}

struct WhirProof {
    bytes32[][][] answers;
    MerkleProof[] merkleProofs;
}

struct MerkleProof {
    bytes32[] decommitments;
    uint32 depth;
}

struct RoundParameters {
    uint256 foldingPowBits;
    uint256 logInvRate;
    uint32 numQueries;
    uint32 oodSamples;
    uint256 powBits;
}

struct WhirConfig {
    uint32 commitmentOodSamples;
    BN254.ScalarField domainGen;
    BN254.ScalarField domainGenInv;
    uint256 domainSize;
    BN254.ScalarField expDomainGen;
    uint256 finalFoldingPowBits;
    uint256 finalLogInvRate;
    uint256 finalPowBits;
    uint32 finalQueries;
    uint128 finalSumcheckRounds;
    uint256 foldingFactor;
    uint256 maxPow;
    uint256 numVariables;
    RoundParameters[] roundParameters;
    uint256 securityLevel;
    uint256 startingFoldingPowBits;
    uint256 startingLogInvRate;
}

struct ParsedRound {
    BN254.ScalarField[] foldingRandomness;
    BN254.ScalarField[] oodPoints;
    BN254.ScalarField[] stirChallengePoints;
    BN254.ScalarField[] combinationRandomness;
}
