// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// forgefmt: disable-start
import {GatewayTest, mTokenGateway, AssetMock} from "./GatewayTest.sol";

import {mTokenProofDecoderLib} from "../../src/libraries/mTokenProofDecoderLib.sol";
// forgefmt: disable-end

/// @title Gateway Invariant Test
/// @custom:command forge test --match-contract GatewayInvariantTest
contract GatewayInvariantTest is GatewayTest {
    /// GHOST VARIABLES
    ////////////////////////////////////////////////////////////////

    // Tracks the total amount deposited by a user on a gateway.
    mapping(mTokenGateway gateway => mapping(address user => uint256 amount))
        amountIns;

    // Tracks the total amount withdrawed by a user on a gateway.
    mapping(mTokenGateway gateway => mapping(address user => uint256 amount))
        amountOuts;

    // Models the maximum cumulative credit proven from the host chain for a user's withdrawals.
    // This value can only increase, simulating new proofs arriving.
    mapping(mTokenGateway gateway => mapping(address user => uint256 amount))
        public provenCreditOut;

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

    function increaseAmountOut(
        mTokenGateway gateway,
        address user,
        uint256 amount
    )
        private
    {
        amountOuts[gateway][user] += amount;
    }

    function getAmountOut(
        mTokenGateway gateway,
        address user
    )
        private
        view
        returns (uint256 amount)
    {
        amount = amountOuts[gateway][user];
    }

    function increaseProvenCreditOut(
        mTokenGateway gateway,
        address user,
        uint256 amount
    )
        private
    {
        provenCreditOut[gateway][user] += amount;
    }

    function getProvenCreditOut(
        mTokenGateway gateway,
        address user
    )
        internal
        view
        returns (uint256 amount)
    {
        amount = provenCreditOut[gateway][user];
    }

    /// SETUP
    ////////////////////////////////////////////////////////////////

    function setUp() external {
        setupGatewayTest();
        targetContract(address(this));
    }

    /// FUZZ ACTIONS
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
            getMaxAmount(params.gateway)
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

    struct WithdrawExtensionCallFuzz {
        uint256 gatewayId;
        uint256 userId;
        uint256 amount;
    }

    struct WithdrawExtensionCallParams {
        mTokenGateway gateway;
        address user;
        uint256 amount;
    }

    function bind(WithdrawExtensionCallFuzz memory fuzz)
        internal
        view
        returns (WithdrawExtensionCallParams memory params)
    {
        params.gateway = getRandomGateway(fuzz.gatewayId);
        params.user = getRandomUser(fuzz.userId);
        params.amount = bound(
            fuzz.amount, //
            1,
            getMaxAmount(params.gateway)
        );
    }

    function withdrawExtensionCall(WithdrawExtensionCallFuzz memory fuzz)
        external
    {
        WithdrawExtensionCallParams memory params = bind(fuzz);
        increaseProvenCreditOut({
            gateway: params.gateway,
            user: params.user,
            amount: params.amount
        });
    }

    struct BorrowExtensionCallFuzz {
        uint256 gatewayId;
        uint256 userId;
        uint256 amount;
    }

    struct BorrowExtensionCallParams {
        mTokenGateway gateway;
        address user;
        uint256 amount;
    }

    function bind(BorrowExtensionCallFuzz memory fuzz)
        internal
        view
        returns (BorrowExtensionCallParams memory params)
    {
        params.gateway = getRandomGateway(fuzz.gatewayId);
        params.user = getRandomUser(fuzz.userId);
        params.amount = bound(
            fuzz.amount, //
            1,
            getMaxAmount(params.gateway)
        );
    }

    function borrowExtensionCall(BorrowExtensionCallFuzz memory fuzz)
        external
    {
        BorrowExtensionCallParams memory params = bind(fuzz);
        increaseProvenCreditOut({
            gateway: params.gateway,
            user: params.user,
            amount: params.amount
        });
    }

    struct OutHereFuzz {
        uint256 gatewayId;
        uint256 userId;
        uint256 amount;
    }

    struct OutHereParams {
        mTokenGateway gateway;
        AssetMock asset;
        address user;
        uint256 amount;
        bytes journalData;
        bytes seal;
        uint256[] amounts;
        address receiver;
    }

    function bind(OutHereFuzz memory fuzz)
        internal
        view
        returns (OutHereParams memory params)
    {
        params.gateway = getRandomGateway(fuzz.gatewayId);
        params.asset = AssetMock(payable(params.gateway.underlying()));
        params.user = getRandomUser(fuzz.userId);

        uint256 currentProvenCredit = getProvenCreditOut(
            params.gateway, //
            params.user
        );
        uint256 currentWithdrawnAmount =
            params.gateway.accAmountOut(params.user);
        uint256 availableToWithdraw =
            currentProvenCredit - currentWithdrawnAmount;
        if (availableToWithdraw > 0) {
            params.amount = bound(fuzz.amount, 1, availableToWithdraw);
        }

        params.receiver = params.user;

        bytes[] memory journals = new bytes[](1);
        journals[0] = mTokenProofDecoderLib.encodeJournal({
            sender: params.user,
            market: address(params.gateway),
            accAmountIn: 0, // Not relevant for this action
            accAmountOut: currentProvenCredit,
            chainId: 59144, // Linea (Host)
            dstChainId: uint32(block.chainid),
            L1inclusion: false // Not checked by batch submitter
        });
        params.journalData = abi.encode(journals);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = params.amount;
        params.amounts = amounts;
    }

    function skip(OutHereParams memory params) internal pure returns (bool) {
        if (params.amount == 0) {
            return true;
        }

        return false;
    }

    function outHere(OutHereFuzz memory fuzz) external {
        OutHereParams memory params = bind(fuzz);

        if (skip(params)) {
            return;
        }

        // Assuming liquidity is enough
        params.asset.mint(address(params.gateway), params.amount);

        try params.gateway.outHere({
            journalData: params.journalData,
            seal: params.seal,
            amounts: params.amounts,
            receiver: params.receiver
        }) {
            increaseAmountOut({
                gateway: params.gateway,
                user: params.user,
                amount: params.amount
            });
        } catch {
            assert(false);
        }
    }

    /// INVARIANTS
    ////////////////////////////////////////////////////////////////

    function property_getProof(
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
        uint256 actualAmountOut = getAmountOut({
            gateway: gateway, //
            user: user
        });
        (uint256 amountIn, uint256 amountOut) = gateway.getProofData(user, 0);
        assertEq(actualAmountIn, amountIn, "accAmountIn invalid");
        assertEq(actualAmountOut, amountOut, "accAmountOut invalid");
    }

    function invariant_gateway() external view {
        for (uint256 i = 0; i < gateways.length; i++) {
            mTokenGateway gateway = gateways[i];
            for (uint256 j = 0; j < users.length; j++) {
                address user = users[j];
                property_getProof(gateway, user);
            }
        }
    }
}
