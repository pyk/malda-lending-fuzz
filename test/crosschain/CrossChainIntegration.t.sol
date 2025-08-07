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
    function setUp() external {
        setupCrossChainTest();
    }

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

    struct SupplyAndMintState {
        uint256 accAmountInGateway;
        uint256 mTokenBalance;
        uint256 accAmountInHost;
        uint256 exchangeRate;
    }

    function snapshot(SupplyAndMintParams memory params)
        internal
        view
        returns (SupplyAndMintState memory state)
    {
        (state.accAmountInGateway,) = gateway.getProofData(params.receiver, 0);
        state.mTokenBalance = market.balanceOf(params.receiver);
        (state.accAmountInHost,) = market.getProofData(
            params.receiver, //
            ETHEREUM_CHAIN_ID
        );
        state.exchangeRate = market.exchangeRateStored();
    }

    /// @custom:property [CC01] Verifies the end-to-end flow for a cross-chain supply.
    /// @dev A user supplies underlying on an extension chain and successfully
    ///      claims mTokens on the host chain.
    function testFuzz_SupplyAndBatchProcessMint(SupplyAndMintFuzz memory fuzz)
        external
    {
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
        uint256 expectedMTokens = (params.amount * 1e18) / pre.exchangeRate;
        assertEq(
            post.mTokenBalance,
            pre.mTokenBalance + expectedMTokens - 1000, // First mint
            "Host: Incorrect number of mTokens minted"
        );
    }
}
