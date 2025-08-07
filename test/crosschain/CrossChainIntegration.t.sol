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
    uint32 private constant LINEA_CHAIN_ID = 59144;

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
        params.amount = bound(fuzz.amount, 1, getMaxAmount(gateway));

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
            uint32(block.chainid),
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

    /// @custom:property [CCI01] Verifies the end-to-end flow for a cross-chain supply.
    /// @dev A user supplies underlying on an extension chain and successfully
    ///      claims mTokens on the host chain.
    function testFuzz_SupplyAndBatchProcessMint(SupplyAndMintFuzz memory fuzz)
        external
    {
        SupplyAndMintParams memory params = bind(fuzz);

        gatewayUnderlying.mint(params.user, params.amount);
        vm.prank(params.user);
        gatewayUnderlying.approve(address(gateway), params.amount);

        // User supplies underlying asset on the extension chain
        vm.prank(params.user);
        try gateway.supplyOnHost({
            amount: params.amount,
            receiver: params.receiver,
            lineaSelector: params.lineaSelector
        }) {} catch {
            assert(false);
        }

        // Get state before the host chain transaction
        uint256 mTokensBefore = market.balanceOf(params.receiver);
        (uint256 claimedAmountBefore,) =
            market.getProofData(params.receiver, uint32(block.chainid));

        // Sequencer observes the event and creates the batch message for the host chain
        BatchSubmitter.BatchProcessMsg memory batchMsg = createBatchMsg(params);

        // Sequencer calls the batch submitter on the host chain
        try batchSubmitter.batchProcess(batchMsg) {}
        catch {
            assert(false);
        }

        // Get state after the host chain transaction
        uint256 mTokensAfter = market.balanceOf(params.receiver);
        (uint256 claimedAmountAfter,) =
            market.getProofData(params.receiver, uint32(block.chainid));

        assertTrue(
            mTokensAfter > mTokensBefore,
            "User did not receive mTokens on host chain"
        );
        assertEq(
            claimedAmountAfter,
            claimedAmountBefore + params.amount,
            "Host chain did not update claimed amount correctly"
        );
    }
}
