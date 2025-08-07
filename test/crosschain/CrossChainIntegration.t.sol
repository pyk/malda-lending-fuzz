// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// forgefmt: disable-start
import {
    CrossChainTest,
    mErc20Host,
    mTokenGateway,
    BatchSubmitter
} from "./CrossChainTest.sol";
import {mTokenProofDecoderLib} from "../../src/libraries/mTokenProofDecoderLib.sol";
// forgefmt: disable-end

/// @title Cross Chain Integration Test
/// @custom:command forge test --match-contract CrossChainIntegrationTest
contract CrossChainIntegrationTest is CrossChainTest {
    ///

    /// SETUP
    ////////////////////////////////////////////////////////////////

    function setUp() external {
        setupCrossChainTest();

        // Initial liquidity
        marketUnderlying.mint(address(this), 10 * 1e18);
        vm.prank(address(this));
        marketUnderlying.approve(address(market), type(uint256).max);

        vm.prank(address(this));
        market.mint(marketUnderlying.balanceOf(address(this)), address(this), 0);
    }

    /// SUPPLY AND MINT
    ////////////////////////////////////////////////////////////////

    struct SupplyAndMintFuzz {
        uint256 userId;
        uint256 receiverId;
        uint256 amount;
    }

    struct SupplyAndMintParams {
        address user;
        address receiver;
        uint256 amount;
        bytes4 lineaSelector;
    }

    struct SupplyAndMintState {
        // Extension chain state
        uint256 accAmountInGateway;
        // Host chain state
        uint256 mTokenBalanceHost;
        uint256 accAmountInHost;
        uint256 exchangeRateHost;
    }

    function bind(SupplyAndMintFuzz memory fuzz)
        internal
        view
        returns (SupplyAndMintParams memory params)
    {
        params.user = getRandomUser(fuzz.userId);
        params.receiver = getRandomUser(fuzz.receiverId);
        params.amount = bound(
            fuzz.amount,
            getMinAmount(address(gateway)),
            getMaxAmount(address(gateway))
        );

        // bytes4[4] memory lineaSelectors = [
        //     mErc20Host.mintExternal.selector,
        //     mErc20Host.repayExternal.selector,
        //     mTokenGateway.outHere.selector,
        //     ""
        // ];
        // params.lineaSelector = lineaSelectors[bound(
        //     fuzz.lineaSelectorId, 0, lineaSelectors.length - 1
        // )];
        params.lineaSelector = mErc20Host.mintExternal.selector;
    }

    function createBatchMsg(SupplyAndMintParams memory params)
        internal
        view
        returns (BatchSubmitter.BatchProcessMsg memory batchMsg)
    {
        address[] memory receivers = new address[](1);
        receivers[0] = params.receiver;
        batchMsg.receivers = receivers;

        bytes[] memory journals = new bytes[](1);
        journals[0] = mTokenProofDecoderLib.encodeJournal(
            params.receiver,
            address(market),
            gateway.accAmountIn(params.receiver),
            gateway.accAmountOut(params.receiver),
            ETHEREUM_CHAIN_ID,
            LINEA_CHAIN_ID,
            false
        );
        batchMsg.journalData = abi.encode(journals);

        batchMsg.seal = "";

        address[] memory mTokens = new address[](1);
        mTokens[0] = address(market);
        batchMsg.mTokens = mTokens;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = params.amount;
        batchMsg.amounts = amounts;

        uint256[] memory minAmountsOut = new uint256[](1);
        minAmountsOut[0] = 0;
        batchMsg.minAmountsOut = minAmountsOut;

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = params.lineaSelector;
        batchMsg.selectors = selectors;

        bytes32[] memory initHashes = new bytes32[](1);
        initHashes[0] = bytes32(uint256(1));
        batchMsg.initHashes = initHashes;

        batchMsg.startIndex = 0;
    }

    function snapshot(SupplyAndMintParams memory params)
        internal
        view
        returns (SupplyAndMintState memory state)
    {
        (state.accAmountInGateway,) = gateway.getProofData(params.receiver, 0);
        state.mTokenBalanceHost = market.balanceOf(params.receiver);
        (state.accAmountInHost,) = market.getProofData(
            params.receiver, //
            ETHEREUM_CHAIN_ID
        );
        state.exchangeRateHost = market.exchangeRateStored();
    }

    /// @custom:property [CC01] Verifies the end-to-end flow for a cross-chain supply.
    /// @dev A user supplies underlying on an extension chain and successfully
    ///      claims mTokens on the host chain.
    function testFuzz_SupplyAndMint(SupplyAndMintFuzz memory fuzz) external {
        SupplyAndMintParams memory params = bind(fuzz);

        vm.chainId(ETHEREUM_CHAIN_ID);
        gatewayUnderlying.mint(params.user, params.amount);
        vm.prank(params.user);
        gatewayUnderlying.approve(address(gateway), params.amount);

        SupplyAndMintState memory pre = snapshot(params);

        // User supplies underlying asset on the extension chain
        vm.prank(params.user);
        try gateway.supplyOnHost({
            amount: params.amount,
            receiver: params.receiver,
            lineaSelector: params.lineaSelector
        }) {} catch {
            assert(false);
        }

        // Sequencer observes the event and creates the batch message for the host chain
        BatchSubmitter.BatchProcessMsg memory batchMsg = createBatchMsg(params);

        vm.chainId(LINEA_CHAIN_ID);

        // Sequencer calls the batch submitter on the host chain
        try batchSubmitter.batchProcess(batchMsg) {}
        catch {
            assert(false);
        }

        SupplyAndMintState memory post = snapshot(params);

        assertEq(
            post.accAmountInGateway,
            pre.accAmountInGateway + params.amount,
            "Gateway: accAmountIn did not increase correctly"
        );
        assertEq(
            post.accAmountInHost,
            pre.accAmountInHost + params.amount,
            "Host: Claimed amount (accAmountIn) did not increase correctly"
        );
        uint256 expectedMTokens = (params.amount * 1e18) / pre.exchangeRateHost;
        assertEq(
            post.mTokenBalanceHost,
            pre.mTokenBalanceHost + expectedMTokens,
            "Host: Incorrect number of mTokens minted"
        );
    }

    /// WITHDRAW AND CLAIM
    ////////////////////////////////////////////////////////////////

    struct WithdrawAndClaimFuzz {
        uint256 userId;
        uint256 initialBalance;
        uint256 mTokenMintAmount;
        uint256 mTokenReceiverId;
        uint256 mTokenMinAmountOut;
    }

    struct WithdrawAndClaimParams {
        address user;
        uint256 initialBalance;
        uint256 mTokenMintAmount;
        address mTokenReceiver;
        uint256 mTokenMinAmountOut;
        bytes4 lineaSelector;
    }

    struct WithdrawAndClaimState {
        // Host chain state
        uint256 mTokenBalanceHost;
        uint256 accAmountOutHost;
        uint256 exchangeRateHost;
        // Extension chain state
        uint256 underlyingBalanceGateway;
        uint256 underlyingBalanceUser;
        uint256 accAmountOutGateway;
    }

    function bind(WithdrawAndClaimFuzz memory fuzz)
        internal
        view
        returns (WithdrawAndClaimParams memory params)
    {
        params.user = getRandomUser(fuzz.userId);
        params.initialBalance = bound(
            fuzz.initialBalance,
            getMinAmount(address(gateway)),
            getMaxAmount(address(gateway))
        );
        params.mTokenMintAmount = bound(
            fuzz.mTokenMintAmount,
            getMinAmount(address(gateway)),
            params.initialBalance
        );
        params.mTokenReceiver = getRandomUser(fuzz.mTokenReceiverId);
        params.mTokenMinAmountOut = 0;
        params.lineaSelector = mTokenGateway.outHere.selector;
    }

    // Takes a snapshot of all relevant state across both chains
    function snapshot(WithdrawAndClaimParams memory params)
        internal
        view
        returns (WithdrawAndClaimState memory state)
    {
        // Host Chain State
        state.mTokenBalanceHost = market.balanceOf(params.mTokenReceiver);
        (, state.accAmountOutHost) = market.getProofData(
            params.mTokenReceiver, //
            ETHEREUM_CHAIN_ID
        );

        // Extension Chain State
        state.underlyingBalanceUser =
            gatewayUnderlying.balanceOf(params.mTokenReceiver);
        state.accAmountOutGateway = gateway.accAmountOut(params.mTokenReceiver);
    }

    function createBatchMsg(WithdrawAndClaimParams memory params)
        internal
        view
        returns (BatchSubmitter.BatchProcessMsg memory batchMsg)
    {
        address[] memory receivers = new address[](1);
        receivers[0] = params.mTokenReceiver;
        batchMsg.receivers = receivers;

        // The journal must reflect the state on the HOST chain
        (uint256 accAmountIn, uint256 accAmountOut) = market.getProofData(
            params.mTokenReceiver, //
            ETHEREUM_CHAIN_ID
        );
        bytes[] memory journals = new bytes[](1);
        journals[0] = mTokenProofDecoderLib.encodeJournal(
            params.mTokenReceiver,
            address(gateway),
            accAmountIn,
            accAmountOut,
            LINEA_CHAIN_ID,
            ETHEREUM_CHAIN_ID,
            false
        );
        batchMsg.journalData = abi.encode(journals);

        batchMsg.seal = "";

        address[] memory mTokens = new address[](1);
        mTokens[0] = address(gateway);
        batchMsg.mTokens = mTokens;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = params.mTokenMintAmount; // one shot; so its ok
        batchMsg.amounts = amounts;

        uint256[] memory minAmountsOut = new uint256[](1);
        minAmountsOut[0] = 0;
        batchMsg.minAmountsOut = minAmountsOut;

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = params.lineaSelector;
        batchMsg.selectors = selectors;

        bytes32[] memory initHashes = new bytes32[](1);
        initHashes[0] = bytes32(uint256(1));
        batchMsg.initHashes = initHashes;

        batchMsg.startIndex = 0;
    }

    /// @custom:property [CC02] Verifies the end-to-end flow for a cross-chain withdrawal.
    /// @dev A user initiates a withdrawal on the host chain and successfully
    ///      claims the underlying asset on the extension chain.
    function testFuzz_WithdrawAndClaim(WithdrawAndClaimFuzz memory fuzz)
        external
    {
        WithdrawAndClaimParams memory params = bind(fuzz);

        marketUnderlying.mint(params.user, params.initialBalance);
        vm.prank(params.user);
        marketUnderlying.approve(address(market), type(uint256).max);

        vm.prank(params.user);
        market.mint(
            params.mTokenMintAmount,
            params.mTokenReceiver,
            params.mTokenMinAmountOut
        );

        WithdrawAndClaimState memory pre = snapshot(params);

        // User initiates withdrawal on the Host chain.
        vm.chainId(LINEA_CHAIN_ID);
        vm.prank(params.mTokenReceiver);
        // ActionType 1 corresponds to a withdrawal.
        market.performExtensionCall(
            1, //
            pre.mTokenBalanceHost,
            ETHEREUM_CHAIN_ID
        );

        // Sequencer observes the event and creates the batch message for the extension chain
        BatchSubmitter.BatchProcessMsg memory batchMsg = createBatchMsg(params);

        vm.chainId(ETHEREUM_CHAIN_ID);

        // Ensure the Gateway on the Extension chain has liquidity
        gatewayUnderlying.mint(address(gateway), params.mTokenMintAmount);

        // Sequencer calls the batch submitter on the extension chain
        try batchSubmitter.batchProcess(batchMsg) {}
        catch {
            assert(false);
        }

        WithdrawAndClaimState memory post = snapshot(params);

        // Assert Host Chain State Changes
        assertEq(
            post.accAmountOutHost,
            pre.accAmountOutHost + params.mTokenMintAmount,
            "Host: accAmountOut did not increase correctly"
        );

        // Assert Extension Chain State Changes
        assertEq(
            post.underlyingBalanceUser,
            pre.underlyingBalanceUser + params.mTokenMintAmount,
            "Gateway: User did not receive underlying"
        );
        assertEq(
            post.accAmountOutGateway,
            pre.accAmountOutGateway + params.mTokenMintAmount,
            "Gateway: accAmountOut did not increase correctly"
        );
    }
}
