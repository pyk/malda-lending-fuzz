// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// forgefmt: disable-start
import {GatewayTest, mTokenGateway, AssetMock, BatchSubmitter} from "./GatewayTest.sol";

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

    struct BatchProcessFuzz {
        uint256 gatewayId;
        uint256 userId;
        uint256 amount;
    }

    struct BatchProcessParams {
        mTokenGateway gateway;
        address user;
        uint256 amount;
        BatchSubmitter.BatchProcessMsg data;
    }

    function bind(BatchProcessFuzz memory fuzz)
        internal
        view
        returns (BatchProcessParams memory params)
    {
        params.gateway = getRandomGateway(fuzz.gatewayId);
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

        address[] memory receivers = new address[](1);
        receivers[0] = params.user;

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
        bytes memory journalData = abi.encode(journals);

        address[] memory mTokens = new address[](1);
        mTokens[0] = address(params.gateway);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = params.amount;

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = mTokenGateway.outHere.selector;

        bytes32[] memory initHashes = new bytes32[](1);
        initHashes[0] = bytes32(0);

        params.data = BatchSubmitter.BatchProcessMsg({
            receivers: receivers,
            journalData: journalData,
            seal: "",
            mTokens: mTokens,
            amounts: amounts,
            minAmountsOut: amounts,
            selectors: selectors,
            initHashes: initHashes,
            startIndex: 0
        });
    }

    function batchProcess(BatchProcessFuzz memory fuzz) external {
        BatchProcessParams memory params = bind(fuzz);

        try batchSubmitter.batchProcess(params.data) {}
        catch {
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
