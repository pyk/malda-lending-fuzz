// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {GatewayTest, mTokenGateway, AssetMock} from "./GatewayTest.sol";

/// @title Gateway Invariant Test
/// @custom:command forge test --match-contract GatewayInvariantTest
contract GatewayInvariantTest is GatewayTest {
    /// GHOST VARIABLES: ACC AMOUNT IN
    ////////////////////////////////////////////////////////////////

    mapping(mTokenGateway gateway => mapping(address user => uint256 amount))
        amountIns;

    function increaseAmountIn(
        mTokenGateway gateway,
        address user,
        uint256 amount
    )
        private
    {
        amountIns[gateway][user] += amount;
    }

    function getAmountIn(
        mTokenGateway gateway,
        address user
    )
        private
        view
        returns (uint256 amount)
    {
        amount = amountIns[gateway][user];
    }

    /// SETUP
    ////////////////////////////////////////////////////////////////

    function setUp() external {
        setupGatewayTest();
        targetContract(address(this));
    }

    /// SUPPLY ON HOST
    ////////////////////////////////////////////////////////////////

    struct SupplyOnHostFuzz {
        uint256 gatewayId;
        uint256 userId;
        uint256 amount;
        uint256 receiverId;
    }

    struct SupplyOnHostParams {
        mTokenGateway gateway;
        AssetMock asset;
        address user;
        uint256 amount;
        address receiver;
    }

    function bind(SupplyOnHostFuzz memory fuzz)
        internal
        view
        returns (SupplyOnHostParams memory params)
    {
        params.gateway = getRandomGateway(fuzz.gatewayId);
        params.asset = AssetMock(payable(params.gateway.underlying()));
        params.user = getRandomUser(fuzz.userId);
        params.amount = bound(
            fuzz.amount, //
            1,
            getMaxSupplyAmount(params.gateway)
        );
        params.receiver = getRandomUser(fuzz.receiverId);
    }

    function supplyOnHost(SupplyOnHostFuzz memory fuzz) external {
        SupplyOnHostParams memory params = bind(fuzz);

        params.asset.mint(params.user, params.amount);
        vm.prank(params.user);
        params.asset.approve(
            address(params.gateway), //
            params.amount
        );
        vm.deal(params.user, GAS_FEE);

        vm.prank(params.user);
        try params.gateway.supplyOnHost{value: GAS_FEE}(
            params.amount, params.receiver, ""
        ) {
            increaseAmountIn({
                gateway: params.gateway,
                user: params.receiver,
                amount: params.amount
            });
        } catch {
            assert(false);
        }
    }

    /// INVARIANTS
    ////////////////////////////////////////////////////////////////

    function property_accAmountIn(
        mTokenGateway gateway,
        address user
    )
        internal
        view
    {
        uint256 actualAmountIn = getAmountIn({
            gateway: gateway, //
            user: user
        });
        uint256 amountIn = gateway.accAmountIn(user);
        assertEq(actualAmountIn, amountIn, "accAmountIn invalid");
    }

    function invariant_gateway() external view {
        for (uint256 i = 0; i < gateways.length; i++) {
            mTokenGateway gateway = gateways[i];
            for (uint256 j = 0; j < users.length; j++) {
                address user = users[j];
                property_accAmountIn(gateway, user);
            }
        }
    }
}
