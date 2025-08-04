// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {mTokenGateway} from "src/mToken/extension/mTokenGateway.sol";
import {AssetMock} from "test/mocks/AssetMock.sol";

import {Handler} from "./Handler.sol";

contract GatewayHandler is Handler {
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address carol = makeAddr("carol");

    mTokenGateway gateway;
    AssetMock underlying;

    mapping(address => uint256) public accAmountIn;
    mapping(address => uint256) public accAmountOut;

    constructor(mTokenGateway _gateway, AssetMock _underlying) {
        gateway = _gateway;
        underlying = _underlying;

        actors = new address[](3);
        actors[0] = alice;
        actors[1] = bob;
        actors[2] = carol;
    }

    function supplyOnHost(
        uint256 actorId,
        uint96 amount,
        address receiver
    )
        external
        useActor(actorId)
    {
        amount = uint96(bound(amount, 1, 1000e18));

        underlying.mint(currentActor, amount);
        underlying.approve(address(gateway), amount);

        gateway.supplyOnHost(amount, receiver, "");

        accAmountIn[receiver] += amount;
    }
}
