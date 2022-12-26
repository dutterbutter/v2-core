// SPDX-License-Identifier: UNLICENSED
// solhint-disable max-line-length
pragma solidity >=0.8.13;

import { IERC20 } from "@prb/contracts/token/erc20/IERC20.sol";
import { SD1x18 } from "@prb/math/SD1x18.sol";
import { UD60x18, ud } from "@prb/math/UD60x18.sol";

import { DataTypes } from "src/libraries/DataTypes.sol";
import { Errors } from "src/libraries/Errors.sol";

import { ProTest } from "../ProTest.t.sol";

contract CreateWithDeltas__Test is ProTest {
    /// @dev it should revert.
    function testCannotCreateWithDeltas__LoopCalculationOverflowsBlockGasLimit() external {
        uint40[] memory segmentDeltas = new uint40[](1_000_000);
        vm.expectRevert(bytes(""));
        pro.createWithDeltas(
            defaultArgs.createWithDeltas.sender,
            defaultArgs.createWithDeltas.recipient,
            defaultArgs.createWithDeltas.grossDepositAmount,
            defaultArgs.createWithDeltas.segmentAmounts,
            defaultArgs.createWithDeltas.segmentExponents,
            defaultArgs.createWithDeltas.operator,
            defaultArgs.createWithDeltas.operatorFee,
            defaultArgs.createWithDeltas.token,
            defaultArgs.createWithDeltas.cancelable,
            segmentDeltas
        );
    }

    modifier LoopCalculationsDoNotOverflowBlockGasLimit() {
        _;
    }

    /// @dev it should revert.
    function testCannotCreateWithDeltas__SegmentDeltaCountNotEqual()
        external
        LoopCalculationsDoNotOverflowBlockGasLimit
    {
        uint256 deltaCount = defaultArgs.createWithDeltas.segmentAmounts.length + 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierV2Pro__SegmentCountsNotEqual.selector,
                defaultArgs.createWithDeltas.segmentAmounts.length,
                defaultArgs.createWithDeltas.segmentExponents.length,
                deltaCount
            )
        );
        uint40[] memory segmentDeltas = new uint40[](deltaCount);
        for (uint40 i = 0; i < deltaCount; ) {
            segmentDeltas[i] = i;
            unchecked {
                i += 1;
            }
        }
        pro.createWithDeltas(
            defaultArgs.createWithDeltas.sender,
            defaultArgs.createWithDeltas.recipient,
            defaultArgs.createWithDeltas.grossDepositAmount,
            defaultArgs.createWithDeltas.segmentAmounts,
            defaultArgs.createWithDeltas.segmentExponents,
            defaultArgs.createWithDeltas.operator,
            defaultArgs.createWithDeltas.operatorFee,
            defaultArgs.createWithDeltas.token,
            defaultArgs.createWithDeltas.cancelable,
            segmentDeltas
        );
    }

    modifier SegmentDeltaEqual() {
        _;
    }

    /// @dev it should revert.
    function testCannotCreateWithDeltas__MilestonesCalculationsOverflows__StartTimeGreaterThanCalculatedFirstMilestone()
        external
        LoopCalculationsDoNotOverflowBlockGasLimit
        SegmentDeltaEqual
    {
        uint40 startTime = getBlockTimestamp();
        uint40[] memory segmentDeltas = createDynamicUint40Array(UINT40_MAX, 1);
        uint40[] memory segmentMilestones = new uint40[](2);
        unchecked {
            segmentMilestones[0] = startTime + segmentDeltas[0];
            segmentMilestones[1] = segmentMilestones[0] + segmentDeltas[1];
        }
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierV2Pro__StartTimeGreaterThanFirstMilestone.selector,
                startTime,
                segmentMilestones[0]
            )
        );
        pro.createWithDeltas(
            defaultArgs.createWithDeltas.sender,
            defaultArgs.createWithDeltas.recipient,
            defaultArgs.createWithDeltas.grossDepositAmount,
            defaultArgs.createWithDeltas.segmentAmounts,
            defaultArgs.createWithDeltas.segmentExponents,
            defaultArgs.createWithDeltas.operator,
            defaultArgs.createWithDeltas.operatorFee,
            defaultArgs.createWithDeltas.token,
            defaultArgs.createWithDeltas.cancelable,
            segmentDeltas
        );
    }

    /// @dev it should revert.
    function testCannotCreateWithDeltas__MilestonesCalculationsOverflows__SegmentMilestonesNotOrdered()
        external
        LoopCalculationsDoNotOverflowBlockGasLimit
        SegmentDeltaEqual
    {
        uint40 startTime = getBlockTimestamp();
        uint128[] memory segmentAmounts = createDynamicUint128Array(
            0,
            DEFAULT_SEGMENT_AMOUNTS[0],
            DEFAULT_SEGMENT_AMOUNTS[1]
        );
        SD1x18[] memory segmentExponents = createDynamicArray(
            SD1x18.wrap(1e18),
            DEFAULT_SEGMENT_EXPONENTS[0],
            DEFAULT_SEGMENT_EXPONENTS[1]
        );
        uint40[] memory segmentDeltas = createDynamicUint40Array(uint40(1), UINT40_MAX, 1);
        uint40[] memory segmentMilestones = new uint40[](3);
        unchecked {
            segmentMilestones[0] = startTime + segmentDeltas[0];
            segmentMilestones[1] = segmentMilestones[0] + segmentDeltas[1];
            segmentMilestones[2] = segmentMilestones[1] + segmentDeltas[2];
        }
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierV2Pro__SegmentMilestonesNotOrdered.selector,
                1,
                segmentMilestones[0],
                segmentMilestones[1]
            )
        );
        pro.createWithDeltas(
            defaultArgs.createWithDeltas.sender,
            defaultArgs.createWithDeltas.recipient,
            defaultArgs.createWithDeltas.grossDepositAmount,
            segmentAmounts,
            segmentExponents,
            defaultArgs.createWithDeltas.operator,
            defaultArgs.createWithDeltas.operatorFee,
            defaultArgs.createWithDeltas.token,
            defaultArgs.createWithDeltas.cancelable,
            segmentDeltas
        );
    }

    modifier MilestonesCalculationsDoNotOverflow() {
        _;
    }

    /// @dev it should perform the ERC-20 transfers, emit a CreateProStream event, create the stream, record the
    /// protocol fee, and bump the next stream id.
    ///
    /// The fuzzing ensures that all of the following scenarios are tested:
    ///
    /// - Funder same as and different from sender.
    /// - Funder same as and different from recipient.
    /// - Sender same as and different from recipient.
    /// - Protocol fee zero and non-zero.
    /// - Operator fee zero and non-zero.
    function testCreateWithDeltas(
        address funder,
        address recipient,
        uint128 grossDepositAmount,
        UD60x18 protocolFee,
        address operator,
        UD60x18 operatorFee
    ) external LoopCalculationsDoNotOverflowBlockGasLimit SegmentDeltaEqual MilestonesCalculationsDoNotOverflow {
        vm.assume(funder != address(0) && recipient != address(0) && operator != address(0));
        vm.assume(grossDepositAmount != 0);
        protocolFee = bound(protocolFee, 0, MAX_FEE);
        operatorFee = bound(operatorFee, 0, MAX_FEE);

        // Set the fuzzed protocol fee.
        changePrank(users.owner);
        comptroller.setProtocolFee(defaultArgs.createWithDeltas.token, protocolFee);

        // Make the funder the caller in the rest of this test.
        changePrank(funder);

        // Mint tokens to the funder.
        deal({ token: defaultArgs.createWithDeltas.token, to: funder, give: grossDepositAmount });

        // Approve the SablierV2Linear contract to transfer the tokens from the funder.
        IERC20(defaultArgs.createWithDeltas.token).approve({ spender: address(pro), value: UINT256_MAX });

        // Load the protocol revenues.
        uint128 previousProtocolRevenues = pro.getProtocolRevenues(defaultArgs.createWithDeltas.token);

        // Load the stream id.
        uint256 streamId = pro.nextStreamId();

        // Calculate the fee amounts and the net deposit amount.
        uint128 protocolFeeAmount = uint128(UD60x18.unwrap(ud(grossDepositAmount).mul(protocolFee)));
        uint128 operatorFeeAmount = uint128(UD60x18.unwrap(ud(grossDepositAmount).mul(operatorFee)));
        uint128 netDepositAmount = grossDepositAmount - protocolFeeAmount - operatorFeeAmount;

        // Calculate the segment amounts as two fractions of the net deposit amount, one 20%, the other 80%.
        uint128[] memory segmentAmounts = new uint128[](2);
        segmentAmounts[0] = uint128(UD60x18.unwrap(ud(grossDepositAmount).mul(ud(0.2e18))));
        segmentAmounts[1] = netDepositAmount - segmentAmounts[0];

        // Expect the tokens to be transferred from the funder to the SablierV2Linear contract.
        vm.expectCall(
            defaultArgs.createWithDeltas.token,
            abi.encodeCall(IERC20.transferFrom, (funder, address(pro), grossDepositAmount))
        );

        // Expect the the operator fee to be paid to the operator, if the fee amount is not zero.
        if (operatorFeeAmount > 0) {
            vm.expectCall(
                defaultArgs.createWithDeltas.token,
                abi.encodeCall(IERC20.transfer, (operator, operatorFeeAmount))
            );
        }

        // Create the stream.
        pro.createWithDeltas(
            defaultArgs.createWithDeltas.sender,
            recipient,
            grossDepositAmount,
            segmentAmounts,
            defaultArgs.createWithDeltas.segmentExponents,
            operator,
            operatorFee,
            defaultArgs.createWithDeltas.token,
            defaultArgs.createWithDeltas.cancelable,
            defaultArgs.createWithDeltas.segmentDeltas
        );

        // Assert that the stream was created.
        DataTypes.ProStream memory actualStream = pro.getStream(streamId);
        assertEq(actualStream.cancelable, defaultStream.cancelable);
        assertEq(actualStream.depositAmount, netDepositAmount);
        assertEq(actualStream.isEntity, defaultStream.isEntity);
        assertEq(actualStream.sender, defaultStream.sender);
        assertEqUint128Array(actualStream.segmentAmounts, segmentAmounts);
        assertEq(actualStream.segmentExponents, defaultStream.segmentExponents);
        assertEqUint40Array(actualStream.segmentMilestones, defaultStream.segmentMilestones);
        assertEq(actualStream.startTime, defaultStream.startTime);
        assertEq(actualStream.stopTime, DEFAULT_STOP_TIME);
        assertEq(actualStream.token, defaultStream.token);
        assertEq(actualStream.withdrawnAmount, defaultStream.withdrawnAmount);

        // Assert that the protocol fee was recorded.
        uint128 actualProtocolRevenues = pro.getProtocolRevenues(defaultArgs.createWithDeltas.token);
        uint128 expectedProtocolRevenues = previousProtocolRevenues + protocolFeeAmount;
        assertEq(actualProtocolRevenues, expectedProtocolRevenues);

        // Assert that the next stream id was bumped.
        uint256 actualNextStreamId = pro.nextStreamId();
        uint256 expectedNextStreamId = streamId + 1;
        assertEq(actualNextStreamId, expectedNextStreamId);

        // Assert that the NFT was minted.
        address actualNFTOwner = pro.ownerOf({ tokenId: streamId });
        address expectedNFTOwner = recipient;
        assertEq(actualNFTOwner, expectedNFTOwner);
    }
}
