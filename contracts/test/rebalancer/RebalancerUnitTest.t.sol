// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RebalancerTest} from "./RebalancerTest.sol";
import {IRebalancer} from "../../src/interfaces/IRebalancer.sol";

contract RebalancerUnitTest is RebalancerTest {
    function test_sendMsg_acrossBridge() external {
        uint256 amount = 10 ether;
        deal(address(asset), address(gateway), amount);
        IRebalancer.Msg memory message = IRebalancer.Msg({
            dstChainId: LINEA_CHAIN_ID,
            token: address(asset),
            message: createAcrossBridgeMessage({
                inputAmount: amount,
                outputAmount: amount,
                relayer: address(rebalancer),
                deadline: uint32(block.timestamp) + uint32(1 days),
                exclusivityDeadline: 0
            }),
            bridgeData: ""
        });
        rebalancer.sendMsg(
            address(acrossBridge), //
            address(gateway),
            amount,
            message
        );
    }
}
