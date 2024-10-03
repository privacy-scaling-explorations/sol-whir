// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {BN254} from "solidity-bn254/BN254.sol";

struct SumcheckPolynomial {
    uint256 nVariables;
    BN254.ScalarField[] evaluations;
}

struct SumcheckRound {
    SumcheckPolynomial polynomial;
    uint256 n;
}
