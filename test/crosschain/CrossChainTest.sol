// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// forgefmt: disable-start
import {
    MaldaTest,
    Roles,
    AssetMock,
    mTokenGateway,
    mErc20Host,
    Blacklister,
    RewardDistributor,
    Operator,
    JumpRateModelV4
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
        Roles roles = deployRoles({label: "HostRoles", owner: admin});
        Blacklister blacklister = deployBlacklister({
            label: "HostBlacklister",
            owner: admin,
            rolesContract: roles
        });
        RewardDistributor rewardDistributor = deployRewardDistributor({
            label: "HostRewardDistributor", //
            owner: admin
        });
        Operator operator = deployOperator({
            label: "HostOperator",
            owner: admin,
            rolesContract: roles,
            blacklisterContract: blacklister,
            rewardDistributorContract: rewardDistributor
        });
        JumpRateModelV4 interestRateModel = deployInterestRateModel({
            label: "WETH_HostInterestRateModel",
            owner: admin,
            blocksPerYear: 31536000,
            baseRatePerYear: 0,
            multiplierPerYear: 22498715810630400,
            jumpMultiplierPerYear: 4999999999974048000,
            kink: 900000000000000000 // 90%
        });

        DeployMarketParams memory marketParams = DeployMarketParams({
            symbol: "WETH",
            decimals: 18,
            owner: admin,
            rolesContract: roles,
            operatorContract: operator,
            interestRateModelContract: interestRateModel,
            zkVerifierContract: deployZkVerifier({
                label: "HostZkVerifier",
                owner: admin,
                risc0VerifierContract: deployRisc0VerifierMock({
                    label: "HostRisc0VerifierMock"
                })
            }),
            initialExchangeRate: 2e16
        });

        market = deployMarket(marketParams);
        marketUnderlying = AssetMock(payable(market.underlying()));
    }
}
