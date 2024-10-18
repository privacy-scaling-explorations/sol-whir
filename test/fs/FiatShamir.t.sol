// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {BN254} from "solidity-bn254/BN254.sol";

import {WhirBaseTest} from "../WhirBaseTest.t.sol";
import {FiatShamir} from "../../src/fs/FiatShamir.sol";

contract FiatShamirTest is WhirBaseTest {
    /// @notice test values checked against rust implementation
    function test_deriveChallengesFromScalar_singleScalar() external pure {
        // derive single challenge
        BN254.ScalarField[] memory toHash = new BN254.ScalarField[](1);
        toHash[0] = BN254.ScalarField.wrap(42);
        BN254.ScalarField[] memory challenge = FiatShamir.deriveChallengesFromScalars(toHash, 1);
        assertEqUintScalarField(
            729468372965156355555354389332233798089583474701725319369131474314595715038, challenge[0]
        );

        // derive five challenges
        BN254.ScalarField[] memory challenges = FiatShamir.deriveChallengesFromScalars(toHash, 5);
        assertEqUintScalarField(
            729468372965156355555354389332233798089583474701725319369131474314595715038, challenges[0]
        );
        assertEqUintScalarField(
            18936102730406357255318628827011331276731862500286706093933432411019434973466, challenges[1]
        );
        assertEqUintScalarField(
            6541929584115784620327860332127424392167657064562883012690568595760249538119, challenges[2]
        );
        assertEqUintScalarField(
            20777190247772607223816048268084911929521105146019479864392516211965679784298, challenges[3]
        );
        assertEqUintScalarField(
            9342720647770071610477633136826579252885066390043962637971223879036655112408, challenges[4]
        );
    }

    /// @notice test values checked against rust implementation
    function test_deriveChallengesFromScalar_multipleScalars() external pure {
        // derive single challenge
        BN254.ScalarField[] memory toHash = new BN254.ScalarField[](3);
        toHash[0] = BN254.ScalarField.wrap(42);
        toHash[1] = BN254.ScalarField.wrap(24);
        toHash[2] = BN254.ScalarField.wrap(42);
        BN254.ScalarField[] memory challenge = FiatShamir.deriveChallengesFromScalars(toHash, 1);
        assertEqUintScalarField(
            20272601219932863375093832544253509814432610329127347624764401756649612871576, challenge[0]
        );

        // derive five challenges
        BN254.ScalarField[] memory challenges = FiatShamir.deriveChallengesFromScalars(toHash, 5);
        assertEqUintScalarField(
            20272601219932863375093832544253509814432610329127347624764401756649612871576, challenges[0]
        );
        assertEqUintScalarField(
            11349770981960638342480498240062427971964806006024921722248107767029995752990, challenges[1]
        );
        assertEqUintScalarField(
            7405114114690130500248438548362118856642710846147556793475009453302143762840, challenges[2]
        );
        assertEqUintScalarField(
            263282946699401980800144399449301130259968353935879232687544294237552369384, challenges[3]
        );
        assertEqUintScalarField(
            11707855677730236955305714024852848768653892714154937753505439974607830409137, challenges[4]
        );
    }
}
