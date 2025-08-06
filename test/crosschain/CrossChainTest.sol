// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// forgefmt: disable-start
import {
    MaldaTest,
    Roles,
    AssetMock,
    mTokenGateway
} from "../MaldaTest.sol";
// forgefmt: disable-end

/// @title CrossChainTest
/// @dev Base contract for unit, fuzz and invariant tests
contract CrossChainTest is MaldaTest {
    /// CONTRACTS
    ////////////////////////////////////////////////////////////////

    mTokenGateway gateway;
    AssetMock underlying;

    function setupCrossChainTest() internal {
        setupUsers();
        setupContracts();
    }

    function setupContracts() private {
        setupExtensionChain();
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
        underlying = AssetMock(payable(gateway.underlying()));
    }
}
