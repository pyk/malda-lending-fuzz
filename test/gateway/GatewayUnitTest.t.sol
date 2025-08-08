// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// forgefmt: disable-start
import {GatewayTest, mTokenGateway} from "./GatewayTest.sol";
import {AssetMock} from "../mocks/AssetMock.sol";
import {mTokenProofDecoderLib} from "../../src/libraries/mTokenProofDecoderLib.sol";
import {ImTokenGateway} from "../../src/interfaces/ImTokenGateway.sol";
// forgefmt: disable-end

/// @custom:command forge test --match-contract GatewayUnitTest
contract GatewayUnitTest is GatewayTest {
    function setUp() external {
        setupGatewayTest();
    }

    /// @custom:property GW06
    /// @dev This test simulates a direct replay attack. It confirms that after
    ///      a successful withdrawal, a second attempt with the exact same proof
    ///      journal fails. This validates the transactional security of the
    ///      `outHere` function.
    function test_GW06_ReplayAttackOnWithdrawalFails() external {
        address user = alice;
        mTokenGateway gateway = wethGateway;
        AssetMock underlying = AssetMock(payable(gateway.underlying()));

        uint256 withdrawalCredit = 100e18;
        uint256 withdrawalAmount = 100e18;

        // Fund the gateway with enough liquidity to cover the withdrawal
        underlying.mint(address(gateway), withdrawalCredit);

        // Create a valid journal proving Alice's credit on the host chain
        bytes[] memory journals = new bytes[](1);
        journals[0] = mTokenProofDecoderLib.encodeJournal({
            sender: user,
            market: address(gateway),
            accAmountIn: 0, // Not relevant for withdrawal
            accAmountOut: withdrawalCredit,
            chainId: LINEA_CHAIN_ID,
            dstChainId: uint32(block.chainid),
            L1inclusion: false
        });
        bytes memory journalData = abi.encode(journals);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = withdrawalAmount;

        uint256 userBalanceBefore = underlying.balanceOf(user);
        uint256 gatewayBalanceBefore = underlying.balanceOf(address(gateway));
        uint256 accAmountOutBefore = gateway.accAmountOut(user);

        // Alice successfully withdraws her funds once
        gateway.outHere(journalData, "", amounts, user);

        // Check that the first withdrawal was successful
        assertEq(
            underlying.balanceOf(user),
            userBalanceBefore + withdrawalAmount,
            "User did not receive funds"
        );
        assertEq(
            underlying.balanceOf(address(gateway)),
            gatewayBalanceBefore - withdrawalAmount,
            "Gateway balance not reduced"
        );
        assertEq(
            gateway.accAmountOut(user),
            accAmountOutBefore + withdrawalAmount,
            "Gateway accAmountOut not updated"
        );

        // Attempt to use the same proof again
        vm.expectRevert(ImTokenGateway.mTokenGateway_AmountTooBig.selector);
        gateway.outHere(journalData, "", amounts, user);
    }

    /// @custom:property GW07
    /// @dev This test simulates the self-sequencing path where a regular user
    ///      calls `outHere` with an invalid proof. It confirms the transaction
    ///      reverts due to the cryptographic check in the ZkVerifier, ensuring
    ///      the security of this censorship-resistance mechanism.
    function test_GW07_SelfSequencingWithInvalidProofFails() external {
        address user = alice;
        mTokenGateway gateway = wethGateway;
        AssetMock underlying = AssetMock(payable(gateway.underlying()));

        uint256 withdrawalAmount = 100e18;
        underlying.mint(address(gateway), withdrawalAmount);

        // Create a journal entry. For this test, its contents don't matter,
        // only that the verifier will reject it.
        bytes[] memory journals = new bytes[](1);
        journals[0] = mTokenProofDecoderLib.encodeJournal({
            sender: user,
            market: address(gateway),
            accAmountIn: 0,
            accAmountOut: withdrawalAmount, // A hypothetical credit
            chainId: LINEA_CHAIN_ID,
            dstChainId: uint32(block.chainid),
            L1inclusion: true
        });
        bytes memory journalData = abi.encode(journals);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = withdrawalAmount;

        // Force the ZkVerifier mock to fail the next verification
        risc0Mock.setStatus(true); // true means "shouldRevert"

        uint256 userBalanceBefore = underlying.balanceOf(user);
        uint256 gatewayBalanceBefore = underlying.balanceOf(address(gateway));

        // The call must revert from the verifier mock
        vm.expectRevert("Failure");
        vm.prank(user);
        gateway.outHere(journalData, "", amounts, user);

        // Ensure no funds were moved
        assertEq(
            underlying.balanceOf(user),
            userBalanceBefore,
            "User balance changed on failed tx"
        );
        assertEq(
            underlying.balanceOf(address(gateway)),
            gatewayBalanceBefore,
            "Gateway balance changed on failed tx"
        );
    }

    /// @custom:property GW08
    /// @dev This is the happy-path test for self-sequencing. It ensures that a
    ///      regular user providing a valid proof can successfully withdraw
    ///      their funds, confirming the liveness and functionality of the
    ///      censorship-resistance mechanism.
    function test_GW08_SelfSequencingWithValidProofSucceeds() external {
        address user = alice;
        mTokenGateway gateway = wethGateway;
        AssetMock underlying = AssetMock(payable(gateway.underlying()));

        uint256 withdrawalCredit = 100e18;
        uint256 withdrawalAmount = 100e18;

        underlying.mint(address(gateway), withdrawalAmount);

        // Create a journal representing the user's valid credit
        bytes[] memory journals = new bytes[](1);
        journals[0] = mTokenProofDecoderLib.encodeJournal({
            sender: user,
            market: address(gateway),
            accAmountIn: 0,
            accAmountOut: withdrawalCredit,
            chainId: LINEA_CHAIN_ID,
            dstChainId: uint32(block.chainid),
            L1inclusion: true
        });
        bytes memory journalData = abi.encode(journals);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = withdrawalAmount;

        // Snapshot state before the action
        uint256 userBalanceBefore = underlying.balanceOf(user);
        uint256 gatewayBalanceBefore = underlying.balanceOf(address(gateway));
        uint256 accAmountOutBefore = gateway.accAmountOut(user);

        // The user self-sequences by calling outHere with the valid proof
        vm.prank(user);
        gateway.outHere(journalData, "", amounts, user);

        // Verify the withdrawal was successful and all state was updated
        // correctly
        assertEq(
            underlying.balanceOf(user),
            userBalanceBefore + withdrawalAmount,
            "User did not receive funds"
        );
        assertEq(
            underlying.balanceOf(address(gateway)),
            gatewayBalanceBefore - withdrawalAmount,
            "Gateway balance was not reduced"
        );
        assertEq(
            gateway.accAmountOut(user),
            accAmountOutBefore + withdrawalAmount,
            "Gateway accAmountOut was not updated"
        );
    }
}
