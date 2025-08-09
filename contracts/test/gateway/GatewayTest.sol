// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {
    MaldaTest,
    Roles,
    Blacklister,
    Risc0VerifierMock,
    ZkVerifier,
    BatchSubmitter,
    mTokenGateway
} from "../MaldaTest.sol";

/// @title GatewayTest
/// @dev Base contract for unit, fuzz and invariant tests
contract GatewayTest is MaldaTest {
    address rebalancer = makeAddr("rebalancer");

    /// CONTRACTS
    ////////////////////////////////////////////////////////////////

    Roles roles;
    Blacklister blacklister;
    Risc0VerifierMock risc0Mock;
    ZkVerifier zkVerifier;
    BatchSubmitter batchSubmitter;
    mTokenGateway wethGateway;
    mTokenGateway[] gateways;

    function getRandomGateway(uint256 id)
        internal
        view
        returns (mTokenGateway gateway)
    {
        gateway = gateways[bound(id, 0, gateways.length - 1)];
    }

    /// SETUP
    ////////////////////////////////////////////////////////////////

    function setupGatewayTest() internal {
        setupUsers();
        setupContracts();
        setupGateways();
        setupRoles();
    }

    function setupContracts() private {
        roles = deployRoles({label: "Roles", owner: admin});
        blacklister = deployBlacklister({
            label: "Blacklister",
            owner: admin,
            rolesContract: roles
        });
        risc0Mock = deployRisc0VerifierMock({label: "Risc0VerifierMock"});
        zkVerifier = deployZkVerifier({
            label: "ZkVerifier",
            owner: admin,
            risc0VerifierContract: risc0Mock
        });
        batchSubmitter = deployBatchSubmitter({
            label: "BatchSubmitter",
            owner: admin,
            rolesContract: roles,
            zkVerifierContract: zkVerifier
        });
    }

    function setupGateways() private {
        gateways = new mTokenGateway[](3);

        gateways[0] = deployGateway({
            label: "WETH",
            underlyingDecimals: 18,
            owner: admin,
            rolesContract: roles,
            blacklisterContract: blacklister,
            zkVerifierContract: zkVerifier,
            gasFee: GAS_FEE,
            minSupplyAmount: 0.01 * 1e18,
            maxSupplyAmount: 10 * 1e18
        });
        wethGateway = gateways[0];
        gateways[1] = deployGateway({
            label: "USDT",
            underlyingDecimals: 6,
            owner: admin,
            rolesContract: roles,
            blacklisterContract: blacklister,
            zkVerifierContract: zkVerifier,
            minSupplyAmount: 0.1 * 1e6,
            maxSupplyAmount: 1_000_000 * 1e6,
            gasFee: GAS_FEE
        });
        gateways[2] = deployGateway({
            label: "USDC",
            underlyingDecimals: 6,
            owner: admin,
            rolesContract: roles,
            blacklisterContract: blacklister,
            zkVerifierContract: zkVerifier,
            minSupplyAmount: 0.1 * 1e6,
            maxSupplyAmount: 1_000_000 * 1e6,
            gasFee: GAS_FEE
        });
    }

    function setupRoles() private {
        vm.startPrank(admin);
        roles.allowFor(address(this), roles.PROOF_FORWARDER(), true);
        roles.allowFor(
            address(batchSubmitter), //
            roles.PROOF_BATCH_FORWARDER(),
            true
        );
        roles.allowFor(
            rebalancer, //
            roles.REBALANCER(),
            true
        );
        vm.stopPrank();
    }
}
