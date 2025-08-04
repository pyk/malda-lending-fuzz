// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IGatewayContext, Gateway} from "../IGatewayContext.sol";

contract GatewayHandler is Test {
    IGatewayContext context;

    mapping(address mtoken => mapping(address user => uint256)) internal
        accAmountIn;
    mapping(address mtoken => mapping(address user => uint256)) internal
        accAmountOut;

    constructor(address _context) {
        context = IGatewayContext(_context);
    }

    function increaseAmountIn(
        address _mtoken,
        address _user,
        uint256 _amount
    )
        internal
    {
        accAmountIn[_mtoken][_user] += _amount;
    }

    function getAmounts(
        address _mtoken,
        address _actor
    )
        external
        view
        returns (uint256 amountIn, uint256 amountOut)
    {
        amountIn = accAmountIn[_mtoken][_actor];
        amountOut = accAmountOut[_mtoken][_actor];
    }

    struct SupplyOnHostFuzz {
        uint256 gatewayId;
        uint256 userId;
        uint256 amount;
        uint256 receiverId;
    }

    struct SupplyOnHostParams {
        Gateway gateway;
        address user;
        uint256 amount;
        address receiver;
    }

    function bind(SupplyOnHostFuzz memory _fuzz)
        internal
        view
        returns (SupplyOnHostParams memory params)
    {
        params.gateway = context.getRandomGateway(_fuzz.gatewayId);
        params.user = context.getRandomUser(_fuzz.userId);
        params.amount = bound(_fuzz.amount, 1, params.gateway.maxSupplyAmount);
        params.receiver = context.getRandomUser(_fuzz.receiverId);
    }

    function supplyOnHost(SupplyOnHostFuzz memory _fuzz) external {
        SupplyOnHostParams memory params = bind(_fuzz);
        Gateway memory gateway = params.gateway;

        gateway.underlying.mint(params.user, params.amount);
        vm.prank(params.user);
        gateway.underlying.approve(
            address(gateway.mtoken), //
            params.amount
        );
        vm.deal(params.user, gateway.gasFee);

        vm.prank(params.user);
        try gateway.mtoken.supplyOnHost{value: gateway.gasFee}(
            params.amount, params.receiver, ""
        ) {
            increaseAmountIn({
                _mtoken: address(gateway.mtoken), //
                _user: params.receiver,
                _amount: params.amount
            });
        } catch {
            assert(false);
        }
    }

    function withdrawGasFees(uint256 _gatewayId) external {
        Gateway memory gateway = context.getRandomGateway(_gatewayId);
        vm.prank(gateway.owner);
        gateway.mtoken.withdrawGasFees(payable(gateway.owner));
    }
}
