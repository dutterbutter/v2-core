// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { Errors } from "src/libraries/Errors.sol";
import { LockupDynamic } from "src/types/DataTypes.sol";

import { Dynamic_Unit_Test } from "../Dynamic.t.sol";

contract StreamedAmountOf_Dynamic_Unit_Test is Dynamic_Unit_Test {
    uint256 internal defaultStreamId;

    function setUp() public virtual override {
        Dynamic_Unit_Test.setUp();

        // Create the default stream.
        defaultStreamId = createDefaultStream();
    }

    modifier whenStreamNotActive() {
        _;
    }

    function test_RevertWhen_StreamNull() external whenStreamNotActive {
        uint256 nullStreamId = 1729;
        vm.expectRevert(abi.encodeWithSelector(Errors.SablierV2Lockup_StreamNull.selector, nullStreamId));
        dynamic.streamedAmountOf(nullStreamId);
    }

    function test_StreamedAmountOf_StreamDepleted() external whenStreamNotActive {
        vm.warp({ timestamp: DEFAULT_END_TIME });
        uint128 withdrawAmount = DEFAULT_DEPOSIT_AMOUNT;
        lockup.withdraw({ streamId: defaultStreamId, to: users.recipient, amount: withdrawAmount });
        uint256 actualStreamedAmount = dynamic.streamedAmountOf(defaultStreamId);
        uint256 expectedStreamedAmount = withdrawAmount;
        assertEq(actualStreamedAmount, expectedStreamedAmount, "streamedAmount");
    }

    function test_StreamedAmountOf_StreamCanceled() external {
        vm.warp({ timestamp: DEFAULT_CLIFF_TIME });
        lockup.cancel(defaultStreamId);
        uint256 actualStreamedAmount = dynamic.streamedAmountOf(defaultStreamId);
        uint256 expectedStreamedAmount = DEFAULT_DEPOSIT_AMOUNT - DEFAULT_RETURNED_AMOUNT;
        assertEq(actualStreamedAmount, expectedStreamedAmount, "streamedAmount");
    }

    modifier whenStreamActive() {
        _;
    }

    function test_StreamedAmountOf_StartTimeInTheFuture() external whenStreamActive {
        vm.warp({ timestamp: 0 });
        uint128 actualStreamedAmount = dynamic.streamedAmountOf(defaultStreamId);
        uint128 expectedStreamedAmount = 0;
        assertEq(actualStreamedAmount, expectedStreamedAmount, "streamedAmount");
    }

    function test_StreamedAmountOf_StartTimeInThePresent() external whenStreamActive {
        vm.warp({ timestamp: DEFAULT_START_TIME });
        uint128 actualStreamedAmount = dynamic.streamedAmountOf(defaultStreamId);
        uint128 expectedStreamedAmount = 0;
        assertEq(actualStreamedAmount, expectedStreamedAmount, "streamedAmount");
    }

    modifier whenStartTimeInThePast() {
        _;
    }

    function test_StreamedAmountOf_OneSegment() external whenStreamActive whenStartTimeInThePast {
        // Warp into the future.
        vm.warp({ timestamp: DEFAULT_START_TIME + 2000 seconds });

        // Create a single-element segment array.
        LockupDynamic.Segment[] memory segments = new LockupDynamic.Segment[](1);
        segments[0] = LockupDynamic.Segment({
            amount: DEFAULT_DEPOSIT_AMOUNT,
            exponent: DEFAULT_SEGMENTS[1].exponent,
            milestone: DEFAULT_END_TIME
        });

        // Create the stream with the one-segment array.
        uint256 streamId = createDefaultStreamWithSegments(segments);

        // Run the test.
        uint128 actualStreamedAmount = dynamic.streamedAmountOf(streamId);
        uint128 expectedStreamedAmount = 4472.13595499957941e18; // (0.2^0.5)*10,000
        assertEq(actualStreamedAmount, expectedStreamedAmount, "streamedAmount");
    }

    modifier whenMultipleSegments() {
        _;
    }

    function test_StreamedAmountOf_CurrentMilestone1st()
        external
        whenStreamActive
        whenMultipleSegments
        whenStartTimeInThePast
    {
        // Warp one second into the future.
        vm.warp({ timestamp: DEFAULT_START_TIME + 1 });

        // Run the test.
        uint128 actualStreamedAmount = dynamic.streamedAmountOf(defaultStreamId);
        uint128 expectedStreamedAmount = 0.000000053506725e18;
        assertEq(actualStreamedAmount, expectedStreamedAmount, "streamedAmount");
    }

    modifier whenCurrentMilestoneNot1st() {
        _;
    }

    function test_StreamedAmountOf_CurrentMilestoneNot1st()
        external
        whenStreamActive
        whenStartTimeInThePast
        whenMultipleSegments
        whenCurrentMilestoneNot1st
    {
        // Warp into the future. 750 seconds is ~10% of the way in the second segment.
        vm.warp({ timestamp: DEFAULT_START_TIME + DEFAULT_CLIFF_DURATION + 750 seconds });

        // Run the test.
        uint128 actualStreamedAmount = dynamic.streamedAmountOf(defaultStreamId);
        uint128 expectedStreamedAmount = DEFAULT_SEGMENTS[0].amount + 2371.708245126284505e18; // ~7,500*0.1^{0.5}
        assertEq(actualStreamedAmount, expectedStreamedAmount, "streamedAmount");
    }
}
