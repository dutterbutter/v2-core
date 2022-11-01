// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.13;

import { SablierV2LinearUnitTest } from "../SablierV2LinearUnitTest.t.sol";

contract SablierV2Linear__GetDepositAmount is SablierV2LinearUnitTest {
    /// @dev it should return zero.
    function testGetDepositAmount__StreamNonExistent() external {
        uint256 nonStreamId = 1729;
        uint256 actualDepositAmount = sablierV2Linear.getDepositAmount(nonStreamId);
        uint256 expectedDepositAmount = 0;
        assertEq(actualDepositAmount, expectedDepositAmount);
    }

    modifier StreamExistent() {
        _;
    }

    /// @dev it should the correct deposit amount.
    function testGetDepositAmount() external StreamExistent {
        uint256 daiStreamId = createDefaultDaiStream();
        uint256 actualDepositAmount = sablierV2Linear.getDepositAmount(daiStreamId);
        uint256 expectedDepositAmount = daiStream.depositAmount;
        assertEq(actualDepositAmount, expectedDepositAmount);
    }
}