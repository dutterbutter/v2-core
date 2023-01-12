// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.13 <0.9.0;

import { IAdminable } from "@prb/contracts/access/IAdminable.sol";
import { UD60x18, ud } from "@prb/math/UD60x18.sol";

import { Errors } from "src/libraries/Errors.sol";
import { Events } from "src/libraries/Events.sol";

import { ComptrollerTest } from "../ComptrollerTest.t.sol";

contract SetProtocolFee_ComptrollerTest is ComptrollerTest {
    /// @dev it should revert.
    function test_RevertWhen_CallerNotAdmin(address eve) external {
        vm.assume(eve != users.admin);

        // Make Eve the caller in this test.
        changePrank(eve);

        // Run the test.
        vm.expectRevert(abi.encodeWithSelector(IAdminable.Adminable_CallerNotAdmin.selector, users.admin, eve));
        comptroller.setProtocolFee(dai, DEFAULT_MAX_FEE);
    }

    modifier callerAdmin() {
        // Make the admin the caller in the rest of this test suite.
        changePrank(users.admin);
        _;
    }

    /// @dev it should re-set the protocol fee.
    function test_SetProtocolFee_SameFee() external callerAdmin {
        UD60x18 newProtocolFee = ud(0);
        comptroller.setProtocolFee(dai, newProtocolFee);

        UD60x18 actualProtocolFee = comptroller.getProtocolFee(dai);
        UD60x18 expectedProtocolFee = newProtocolFee;
        assertEq(actualProtocolFee, expectedProtocolFee);
    }

    /// @dev it should set the new protocol fee
    function testFuzz_SetProtocolFee_DifferentFee(UD60x18 newProtocolFee) external callerAdmin {
        newProtocolFee = bound(newProtocolFee, 1, DEFAULT_MAX_FEE);
        comptroller.setProtocolFee(dai, newProtocolFee);

        UD60x18 actualProtocolFee = comptroller.getProtocolFee(dai);
        UD60x18 expectedProtocolFee = newProtocolFee;
        assertEq(actualProtocolFee, expectedProtocolFee);
    }
}