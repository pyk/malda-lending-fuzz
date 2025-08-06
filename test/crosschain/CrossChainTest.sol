// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// forgefmt: disable-start
import {
    MaldaTest,
    Roles,
    AssetMock,
    mTokenGateway,
    mErc20Host
} from "../MaldaTest.sol";
// forgefmt: disable-end

/// @title CrossChainTest
/// @dev Base contract for unit, fuzz and invariant tests
contract CrossChainTest is MaldaTest {
    /// CONTRACTS
    ////////////////////////////////////////////////////////////////

    mTokenGateway gateway;
    AssetMock gatewayUnderlying;
    mErc20Host market;
    AssetMock marketUnderlying;

    /// SETUP
    ////////////////////////////////////////////////////////////////

    function setupCrossChainTest() internal {
        setupUsers();
        setupContracts();
    }

    function setupContracts() private {
        setupExtensionChain();
        setupHostChain();
    }

    function setupExtensionChain() private {
        Roles roles = deployRoles({label: "ExtensionRoles", owner: admin});

        gateway = deployGateway({
            label: "WETH",
            underlyingDecimals: 18,
            owner: admin,
            rolesContract: roles,
            blacklisterContract: deployBlacklister({
                label: "ExtensionBlacklister", //
                owner: admin,
                rolesContract: roles
            }),
            zkVerifierContract: deployZkVerifier({
                label: "ExtensionZkVerifier",
                owner: admin,
                risc0VerifierContract: deployRisc0VerifierMock({
                    label: "ExtensionRisc0VerifierMock"
                })
            }),
            gasFee: 0,
            maxSupplyAmount: 100 * 1e18
        });
        gatewayUnderlying = AssetMock(payable(gateway.underlying()));
    }

    function setupHostChain() private {
        market = deployMarket({
            symbol: "WETH",
            decimals: 18,
            owner: admin,
            operatorContract: deployOperator()
        });
    }
}
