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
    JumpRateModelV4,
    BatchSubmitter,
    ZkVerifier,
    ChainlinkFeedMock,
    MixedPriceOracleV4
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
    BatchSubmitter batchSubmitter;

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
        ZkVerifier zkVerifier = deployZkVerifier({
            label: "HostZkVerifier",
            owner: admin,
            risc0VerifierContract: deployRisc0VerifierMock({
                label: "HostRisc0VerifierMock"
            })
        });
        ChainlinkFeedMock wethFeed = deployChainlinkFeedMock(
            "WETHUSDFeed", //
            3000 * 1e8
        );

        DeployMarketParams memory marketParams = DeployMarketParams({
            symbol: "WETH",
            decimals: 18,
            owner: admin,
            rolesContract: roles,
            operatorContract: operator,
            interestRateModelContract: interestRateModel,
            zkVerifierContract: zkVerifier,
            initialExchangeRate: 2e16
        });

        market = deployMarket(marketParams);
        marketUnderlying = AssetMock(payable(market.underlying()));
        batchSubmitter = deployBatchSubmitter({
            label: "HostBatchSubmitter",
            owner: admin,
            rolesContract: roles,
            zkVerifierContract: zkVerifier
        });

        // Prepare configs for the MixedPriceOracleV4
        string[] memory symbols = new string[](1);
        symbols[0] = marketUnderlying.symbol();

        MixedPriceOracleV4.PriceConfig[] memory configs =
            new MixedPriceOracleV4.PriceConfig[](1);
        configs[0] = MixedPriceOracleV4.PriceConfig({
            api3Feed: address(wethFeed),
            eOracleFeed: address(wethFeed),
            toSymbol: "USD",
            underlyingDecimals: 18 // WETH has 18 decimals
        });

        DeployOracleParams memory oracleParams = DeployOracleParams({
            label: "HostOracle",
            rolesContract: roles,
            stalenessPeriod: 3600, // 1 hour
            symbols: symbols,
            configs: configs
        });
        MixedPriceOracleV4 oracle = deployOracle(oracleParams);

        vm.startPrank(admin);
        operator.setPriceOracle(address(oracle));
        operator.supportMarket(address(market));
        operator.setCollateralFactor(address(market), 810000000000000000); // 81% collateral factor
        // operator.setCloseFactor(0.5e18); // 50% close factor
        operator.setLiquidationIncentive(address(market), 1060000000000000000); // 6% liquidation incentive
        vm.stopPrank();

        setupRoles(roles);
    }

    function setupRoles(Roles roles) private {
        vm.startPrank(admin);
        roles.allowFor(address(this), roles.PROOF_FORWARDER(), true);
        roles.allowFor(
            address(batchSubmitter), //
            roles.PROOF_BATCH_FORWARDER(),
            true
        );
        vm.stopPrank();
    }
}
