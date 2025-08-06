// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// forgefmt: disable-start
import {CrossChainTest} from "./CrossChainTest.sol";
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
    }

    function bind(SupplyAndMintFuzz memory fuzz)
        internal
        view
        returns (SupplyAndMintParams memory params)
    {
        params.user = getRandomUser(fuzz.userId);
        params.receiver = getRandomUser(fuzz.receiverId);
        params.amount = bound(fuzz.amount, 1, getMaxAmount(gateway));
    }

    /// @custom:property [CCI01] Verifies the end-to-end flow for a cross-chain supply.
    function testFuzz_SupplyAndMint(SupplyAndMintFuzz memory fuzz) external {
        // A user supplies underlying on an extension chain and successfully
        // claims mTokens on the host chain.

        SupplyAndMintParams memory params = bind(fuzz);

        underlying.mint(params.user, params.amount);
        vm.prank(params.user);
        underlying.approve(address(gateway), params.amount);

        vm.prank(params.user);
        try gateway.supplyOnHost({
            amount: params.amount,
            receiver: params.receiver,
            // TODO: integrate this
            // lineaSelector: mErc20Host.mintExternal.selector
            lineaSelector: ""
        }) {} catch {
            assert(false);
        }

        // TODO: we need gateway here
    }
}
