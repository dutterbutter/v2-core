// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.13;

import { ISablierV2 } from "src/interfaces/ISablierV2.sol";

import { GetProtocolRevenues__Test } from "test/unit/shared/get-protocol-revenues/getProtocolRevenues.t.sol";
import { LinearTest } from "test/unit/linear/LinearTest.t.sol";
import { UnitTest } from "test/unit/UnitTest.t.sol";

contract GetProtocolRevenues__Linear__Test is LinearTest, GetProtocolRevenues__Test {
    function setUp() public virtual override(LinearTest, GetProtocolRevenues__Test) {
        super.setUp();
        sablierV2 = ISablierV2(linear);
    }
}
