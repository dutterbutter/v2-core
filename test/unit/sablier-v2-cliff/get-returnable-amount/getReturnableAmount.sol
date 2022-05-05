// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.13;

import { SablierV2CliffUnitTest } from "../SablierV2CliffUnitTest.t.sol";

contract SablierV2Cliff__GetReturnableAmount__UnitTest is SablierV2CliffUnitTest {
    uint256 internal streamId;

    /// @dev A setup function invoked before each test case.
    function setUp() public override {
        super.setUp();

        // Create the default stream, all tests need one.
        streamId = createDefaultStream();
    }

    /// @dev When the stream does not exist, it should return zero.
    function testGetReturnableAmount__StreamNonExistent() external {
        uint256 nonStreamId = 1729;
        uint256 expectedReturnableAmount = 0;
        uint256 actualReturnableAmount = sablierV2Cliff.getReturnableAmount(nonStreamId);
        assertEq(expectedReturnableAmount, actualReturnableAmount);
    }

    /// @dev When the withdrawable amount is zero and there have been no withdrawals, it should return the
    /// deposit amount.
    function testGetReturnableAmount__WithdrawableAmountZero__NoWithdrawals() external {
        uint256 expectedReturnableAmount = stream.depositAmount;
        uint256 actualReturnableAmount = sablierV2Cliff.getReturnableAmount(streamId);
        assertEq(expectedReturnableAmount, actualReturnableAmount);
    }

    /// @dev When the withdrawable amount is zero and there have been withdrawals, it should return the
    /// correct returnable amount.
    function testGetReturnableAmount__WithdrawableAmountZero__WithWithdrawals() external {
        vm.warp(stream.startTime + DEFAULT_TIME_OFFSET);
        sablierV2Cliff.withdraw(streamId, DEFAULT_WITHDRAW_AMOUNT);
        uint256 expectedReturnableAmount = stream.depositAmount - DEFAULT_WITHDRAW_AMOUNT;
        uint256 actualReturnableAmount = sablierV2Cliff.getReturnableAmount(streamId);
        assertEq(expectedReturnableAmount, actualReturnableAmount);
    }

    /// @dev When the withdrawable amount is not zero and there have been no withdrawals, it should return the
    /// correct returnable amount.
    function testGetReturnableAmount__WithdrawableAmountNotZero__NoWithdrawals() external {
        vm.warp(stream.startTime + DEFAULT_TIME_OFFSET);
        uint256 expectedReturnableAmount = stream.depositAmount - DEFAULT_WITHDRAW_AMOUNT;
        uint256 actualReturnableAmount = sablierV2Cliff.getReturnableAmount(streamId);
        assertEq(expectedReturnableAmount, actualReturnableAmount);
    }

    /// @dev When the withdrawable amount is not zero and there have been withdrawals, it should return the
    /// correct returnable amount.
    function testGetReturnableAmount__WithdrawableAmountNotZero__WithWithdrawals() external {
        vm.warp(stream.startTime + DEFAULT_TIME_OFFSET + 1 seconds);
        sablierV2Cliff.withdraw(streamId, DEFAULT_WITHDRAW_AMOUNT);
        uint256 expectedReturnableAmount = stream.depositAmount - DEFAULT_WITHDRAW_AMOUNT - bn(1);
        uint256 actualReturnableAmount = sablierV2Cliff.getReturnableAmount(streamId);
        assertEq(expectedReturnableAmount, actualReturnableAmount);
    }
}
