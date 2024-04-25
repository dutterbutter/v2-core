// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { LockupTranched } from "src/types/DataTypes.sol";

import { Benchmark_Test } from "./Benchmark.t.sol";

/// @notice Benchmark Test for the LockupTranched contract.
/// @dev This contract creates a markdown file with the gas usage of each function in the benchmarks directory.
contract LockupTranched_Gas_Test is Benchmark_Test {
    function setUp() public override {
        super.setUp();

        lockup = lockupTranched;

        benchmarksFile = string.concat(benchmarksDir, "SablierV2LockupTranched.md");

        // Create the file if it doesn't exist, otherwise overwrite it
        vm.writeFile({
            path: benchmarksFile,
            data: string.concat(
                "# Benchmarks for implementations in the LockupTranched contract\n\n",
                "| Implementation | Gas Usage |\n",
                "| --- | --- |\n"
            )
        });
    }

    function testGas_Implementations() external {
        // Set the caller to recipient for `burn` and change timestamp to end time
        resetPrank({ msgSender: users.recipient });
        vm.warp({ newTimestamp: defaults.END_TIME() });
        gasBurn();

        // Set the caller to sender for the next few calls and change timestamp to before end time
        resetPrank({ msgSender: users.sender });
        vm.warp({ newTimestamp: defaults.WARP_26_PERCENT() });

        gasCancel();

        // Create streams with different number of tranches
        gasCreateWithDurations({ totalTranches: 2 });
        gasCreateWithDurations({ totalTranches: 10 });
        gasCreateWithDurations({ totalTranches: 100 });
        gasCreateWithTimestamps({ totalTranches: 2 });
        gasCreateWithTimestamps({ totalTranches: 10 });
        gasCreateWithTimestamps({ totalTranches: 100 });

        gasRenounce();
        gasWithdraw();

        // Set the caller to recipient for the next call
        resetPrank({ msgSender: users.recipient });
        gasWithdraw_ByRecipient();
    }

    /*//////////////////////////////////////////////////////////////////////////
                        GAS BENCHMARKS FOR CREATE FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function gasCreateWithDurations(uint128 totalTranches) public {
        LockupTranched.CreateWithDurations memory params = _createWithDurationParams(totalTranches);

        uint256 beforeGas = gasleft();
        lockupTranched.createWithDurations(params);
        uint256 afterGas = gasleft();

        dataToAppend = string.concat(
            "| `createWithDurations` (",
            vm.toString(totalTranches),
            " tranches) | ",
            vm.toString(beforeGas - afterGas),
            " |"
        );

        // Append the data to the file
        _appendToFile(benchmarksFile, dataToAppend);
    }

    function gasCreateWithTimestamps(uint128 totalTranches) public {
        LockupTranched.CreateWithTimestamps memory params = _createWithTimestampParams(totalTranches);

        uint256 beforeGas = gasleft();
        lockupTranched.createWithTimestamps(params);
        uint256 afterGas = gasleft();

        dataToAppend = string.concat(
            "| `createWithTimestamps` (",
            vm.toString(totalTranches),
            " tranches) | ",
            vm.toString(beforeGas - afterGas),
            " |"
        );
        // Append the data to the file
        _appendToFile(benchmarksFile, dataToAppend);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    function _createWithDurationParams(uint128 totalTranches)
        private
        view
        returns (LockupTranched.CreateWithDurations memory)
    {
        uint128 amountInEachTranche = defaults.DEPOSIT_AMOUNT() / totalTranches;
        LockupTranched.TrancheWithDuration[] memory tranches_ = new LockupTranched.TrancheWithDuration[](totalTranches);

        // Populate tranches
        for (uint256 i = 0; i < totalTranches; ++i) {
            tranches_[i] = (
                LockupTranched.TrancheWithDuration({ amount: amountInEachTranche, duration: defaults.CLIFF_DURATION() })
            );
        }

        return LockupTranched.CreateWithDurations({
            sender: users.sender,
            recipient: users.recipient,
            totalAmount: defaults.TOTAL_AMOUNT(),
            asset: dai,
            cancelable: true,
            transferable: true,
            tranches: tranches_,
            broker: defaults.broker()
        });
    }

    function _createWithTimestampParams(uint128 totalTranches)
        private
        view
        returns (LockupTranched.CreateWithTimestamps memory)
    {
        uint128 amountInEachTranche = defaults.DEPOSIT_AMOUNT() / totalTranches;

        LockupTranched.Tranche[] memory tranches_ = new LockupTranched.Tranche[](totalTranches);

        // Populate tranches
        for (uint256 i = 0; i < totalTranches; ++i) {
            tranches_[i] = (
                LockupTranched.Tranche({
                    amount: amountInEachTranche,
                    timestamp: uint40(block.timestamp + defaults.CLIFF_DURATION() * (1 + i))
                })
            );
        }

        return LockupTranched.CreateWithTimestamps({
            sender: users.sender,
            recipient: users.recipient,
            totalAmount: defaults.TOTAL_AMOUNT(),
            asset: dai,
            cancelable: true,
            transferable: true,
            startTime: uint40(block.timestamp),
            tranches: tranches_,
            broker: defaults.broker()
        });
    }
}
