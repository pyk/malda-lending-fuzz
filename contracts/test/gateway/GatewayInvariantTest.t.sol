// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// forgefmt: disable-start
import {GatewayTest, mTokenGateway} from "./GatewayTest.sol";
import {AssetMock} from "../mocks/AssetMock.sol";
import {mTokenProofDecoderLib} from "../../src/libraries/mTokenProofDecoderLib.sol";
// forgefmt: disable-end

/// @title Gateway Invariant Test
/// @custom:command forge test --match-contract GatewayInvariantTest
contract GatewayInvariantTest is GatewayTest {
    /// GHOST VARIABLES
    ////////////////////////////////////////////////////////////////

    /// @notice Tracks the total amount deposited by a user on a gateway.
    mapping(mTokenGateway gateway => mapping(address user => uint256 amount))
        amountIns;

    /// @notice Tracks the total amount withdrawed by a user on a gateway.
    mapping(mTokenGateway gateway => mapping(address user => uint256 amount))
        amountOuts;

    /// @notice Models the maximum cumulative credit proven from the host chain
    ///         for a user's withdrawals.
    ///         This value can only increase, simulating new proofs arriving.
    mapping(mTokenGateway gateway => mapping(address user => uint256 amount))
        public hostAmountOut;

    /// @notice Tracks the total deposited amount
    mapping(mTokenGateway gateway => uint256 amount) totalDeposited;

    /// @notice Tracks the total withdrawn amount
    mapping(mTokenGateway gateway => uint256 amount) totalWithdrawn;

    /// @notice Represents a withdrawal request initiated on the host chain,
    ///         pending claim on the extension chain.
    struct PendingWithdrawal {
        mTokenGateway gateway;
        address user;
        uint256 amount;
    }

    PendingWithdrawal[] pendingWithdrawals;

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

    function increaseHostAmountOut(
        mTokenGateway gateway,
        address user,
        uint256 amount
    )
        private
    {
        hostAmountOut[gateway][user] += amount;
    }

    function getHostAmountOut(
        mTokenGateway gateway,
        address user
    )
        internal
        view
        returns (uint256 amount)
    {
        amount = hostAmountOut[gateway][user];
    }

    function increaseTotalDeposited(
        mTokenGateway gateway,
        uint256 amount
    )
        private
    {
        totalDeposited[gateway] += amount;
    }

    function getTotalDeposited(mTokenGateway gateway)
        private
        view
        returns (uint256 amount)
    {
        amount = totalDeposited[gateway];
    }

    function increaseTotalWithdrawn(
        mTokenGateway gateway,
        uint256 amount
    )
        private
    {
        totalWithdrawn[gateway] += amount;
    }

    function getTotalWithdrawn(mTokenGateway gateway)
        private
        view
        returns (uint256 amount)
    {
        amount = totalWithdrawn[gateway];
    }

    function getRandomPendingWithdrawal(uint256 id)
        private
        view
        returns (PendingWithdrawal memory p)
    {
        uint256 count = pendingWithdrawals.length;
        if (count > 0) {
            p = pendingWithdrawals[bound(id, 0, pendingWithdrawals.length - 1)];
        }
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
            getMaxAmount(address(params.gateway))
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
            increaseTotalDeposited({
                gateway: params.gateway,
                amount: params.amount
            });
        } catch {
            assert(false);
        }
    }

    /// CREATE PENDING WITHDRAWAL
    ////////////////////////////////////////////////////////////////

    struct CreatePendingWithdrawalFuzz {
        uint256 gatewayId;
        uint256 userId;
        uint256 amount;
    }

    struct CreatePendingWithdrawalParams {
        mTokenGateway gateway;
        address user;
        uint256 amount;
    }

    function bind(CreatePendingWithdrawalFuzz memory fuzz)
        internal
        view
        returns (CreatePendingWithdrawalParams memory params)
    {
        params.gateway = getRandomGateway(fuzz.gatewayId);
        params.user = getRandomUser(fuzz.userId);
        params.amount = bound(
            fuzz.amount, //
            1,
            getMaxAmount(address(params.gateway))
        );
    }

    function createPendingWithdrawal(CreatePendingWithdrawalFuzz memory fuzz)
        external
    {
        CreatePendingWithdrawalParams memory params = bind(fuzz);
        increaseHostAmountOut({
            gateway: params.gateway,
            user: params.user,
            amount: params.amount
        });
        pendingWithdrawals.push(
            PendingWithdrawal({
                gateway: params.gateway,
                user: params.user,
                amount: params.amount
            })
        );
    }

    /// EXECUTE PENDING WITHDRAWAL
    ////////////////////////////////////////////////////////////////

    struct ExecutePendingWithdrawalFuzz {
        uint256 pendingWithdrawalIndex;
        // outHere params
        uint256 receiverId;
        uint256 outHereAmount;
        // Journal content
        bool l1Inclusion;
    }

    struct ExecutePendingWithdrawalParams {
        // Withdrawal params
        mTokenGateway gateway;
        AssetMock asset;
        address sender;
        // Journal params
        bool l1Inclusion;
        // outHere params
        uint256 amount;
        bytes journalData;
        bytes seal;
        uint256[] amounts;
        address receiver;
    }

    function bind(ExecutePendingWithdrawalFuzz memory fuzz)
        internal
        view
        returns (ExecutePendingWithdrawalParams memory params)
    {
        PendingWithdrawal memory w = getRandomPendingWithdrawal({
            id: fuzz.pendingWithdrawalIndex //
        });
        if (address(w.gateway) == address(0)) {
            return params;
        }
        uint256 accAmountOut = getHostAmountOut(
            params.gateway, //
            params.sender
        );

        params.gateway = w.gateway;
        params.asset = AssetMock(payable(params.gateway.underlying()));

        params.sender = w.user;
        params.l1Inclusion = fuzz.l1Inclusion;
        params.journalData = createJournalData(params);
        params.seal = "";
        if (accAmountOut > 0) {
            params.amount = bound(fuzz.outHereAmount, 1, accAmountOut);
        }

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = params.amount;
        params.amounts = amounts;

        params.receiver = getRandomUser(fuzz.receiverId);
    }

    function skip(ExecutePendingWithdrawalParams memory params)
        private
        pure
        returns (bool)
    {
        if (address(params.gateway) == address(0)) {
            return true;
        }
        if (params.amount == 0) {
            return true;
        }
        return false;
    }

    function createJournalData(ExecutePendingWithdrawalParams memory params)
        internal
        view
        returns (bytes memory journalData)
    {
        uint256 accAmountOut = getHostAmountOut(
            params.gateway, //
            params.sender
        );
        bytes[] memory journals = new bytes[](1);
        journals[0] = mTokenProofDecoderLib.encodeJournal({
            sender: params.sender,
            market: address(params.gateway),
            accAmountIn: 0, // Not relevant for this action
            accAmountOut: accAmountOut,
            chainId: LINEA_CHAIN_ID, // Linea (Host)
            dstChainId: uint32(block.chainid),
            L1inclusion: params.l1Inclusion
        });
        journalData = abi.encode(journals);
    }

    function executePendingWithdrawal(ExecutePendingWithdrawalFuzz memory fuzz)
        external
    {
        ExecutePendingWithdrawalParams memory params = bind(fuzz);
        if (skip(params)) {
            return;
        }

        try params.gateway.outHere({
            journalData: params.journalData,
            seal: params.seal,
            amounts: params.amounts,
            receiver: params.receiver
        }) {
            increaseAmountOut({
                gateway: params.gateway,
                user: params.receiver,
                amount: params.amount
            });
            increaseTotalWithdrawn({
                gateway: params.gateway,
                amount: params.amount
            });
        } catch {
            assert(false);
        }
    }

    /// REBALANCER ACTIONS
    ////////////////////////////////////////////////////////////////

    function extractForRebalancing(
        uint256 gatewayId,
        uint256 amount
    )
        external
    {
        mTokenGateway gateway = getRandomGateway(gatewayId);
        AssetMock asset = AssetMock(payable(gateway.underlying()));
        uint256 balance = asset.balanceOf(address(gateway));
        if (balance == 0) {
            return;
        }

        amount = bound(amount, 1, balance);

        vm.prank(rebalancer);
        try gateway.extractForRebalancing(amount) {
            increaseTotalWithdrawn({gateway: gateway, amount: amount});
        } catch {
            assert(false);
        }
    }

    function depositForRebalancing(
        uint256 gatewayId,
        uint256 amount
    )
        external
    {
        mTokenGateway gateway = getRandomGateway(gatewayId);
        AssetMock asset = AssetMock(payable(gateway.underlying()));
        amount = bound(amount, 1, getMaxAmount(address(gateway)));

        asset.mint(rebalancer, amount);

        vm.prank(rebalancer);
        try asset.transfer(address(gateway), amount) {
            increaseTotalDeposited({gateway: gateway, amount: amount});
        } catch {
            assert(false);
        }
    }

    /// INVARIANTS
    ////////////////////////////////////////////////////////////////

    /// @custom:property GW01
    /// @dev A user's total deposited amount, as tracked by the gateway
    /// contract,
    ///      must always equal the sum of all their successful supply actions.
    function invariant_gatewaySupplyCredit() external view {
        for (uint256 i = 0; i < gateways.length; i++) {
            mTokenGateway gateway = gateways[i];
            for (uint256 j = 0; j < users.length; j++) {
                address user = users[j];

                uint256 gatewayDeposited = gateway.accAmountIn(user);
                uint256 actualDeposited = getAmountIn(gateway, user);

                assertEq(
                    gatewayDeposited,
                    actualDeposited,
                    string.concat(
                        "GW01: Supply Credit Violation for user ",
                        vm.toString(user)
                    )
                );
            }
        }
    }

    /// @custom:property GW02 & GW05
    /// @dev A user's total withdrawn amount on the gateway must never exceed
    ///      the total credit proven for them from the host chain. This prevents
    ///      double-spends and ensures resilience to reordering.
    function invariant_gatewayWithdrawalCredit() external view {
        for (uint256 i = 0; i < gateways.length; i++) {
            mTokenGateway gateway = gateways[i];
            for (uint256 j = 0; j < users.length; j++) {
                address user = users[j];

                uint256 gatewayWithdrawn = gateway.accAmountOut(user);
                uint256 actualWithdrawn = getAmountOut(gateway, user);
                uint256 hostWithdrawn = getHostAmountOut(gateway, user);

                // GW02
                assertEq(
                    gatewayWithdrawn,
                    actualWithdrawn,
                    string.concat(
                        "GW02: accAmountOut differs for user ",
                        vm.toString(user)
                    )
                );

                // GW05
                assertLe(
                    gatewayWithdrawn,
                    hostWithdrawn,
                    string.concat(
                        "GW05: Withdrawal Exceeds Credit Violation for user ",
                        vm.toString(user)
                    )
                );
            }
        }
    }

    /// @custom:property GW04
    /// @dev The total underlying assets held by the gateway must equal
    ///      the net of all deposits and withdrawals (user + rebalancer).
    function invariant_gatewayFundConservation() external view {
        for (uint256 i = 0; i < gateways.length; i++) {
            mTokenGateway gateway = gateways[i];
            AssetMock asset = AssetMock(payable(gateway.underlying()));

            uint256 expectedBalance =
                getTotalDeposited(gateway) - getTotalWithdrawn(gateway);
            uint256 actualBalance = asset.balanceOf(address(gateway));

            assertEq(
                actualBalance,
                expectedBalance,
                string.concat(
                    "GW04: Conservation of Funds Violation for ",
                    vm.toString(address(gateway))
                )
            );
        }
    }
}
