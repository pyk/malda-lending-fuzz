// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// forgefmt: disable-start
import {Test} from "forge-std/Test.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Roles} from "../src/Roles.sol";
import {Blacklister} from "../src/blacklister/Blacklister.sol";
import {Risc0VerifierMock} from "./mocks/Risc0VerifierMock.sol";
import {ZkVerifier} from "../src/verifier/ZkVerifier.sol";
import {AssetMock} from "./mocks/AssetMock.sol";
import {mTokenGateway} from "../src/mToken/extension/mTokenGateway.sol";
import {BatchSubmitter} from "../src/mToken/BatchSubmitter.sol";
import {Operator} from "../src/Operator/Operator.sol";
import {JumpRateModelV4} from "../src/interest/JumpRateModelV4.sol";
import {mErc20Host} from "../src/mToken/host/mErc20Host.sol";
import {RewardDistributor} from "../src/rewards/RewardDistributor.sol";
import {ChainlinkFeedMock} from "./mocks/ChainlinkFeedMock.sol";
import {MixedPriceOracleV4} from "../src/oracles/MixedPriceOracleV4.sol";

// forgefmt: disable-end

/// @title MaldaTest
/// @dev Base contract for unit, fuzz and invariant tests
contract MaldaTest is Test {
    /// USERS
    ////////////////////////////////////////////////////////////////

    address[] users;
    address admin = makeAddr("admin");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address carol = makeAddr("carol");

    function getRandomUser(uint256 id) internal view returns (address user) {
        user = users[bound(id, 0, users.length - 1)];
    }

    function setupUsers() internal {
        users = new address[](3);
        users[0] = alice;
        users[1] = bob;
        users[2] = carol;
    }

    /// GATEWAY DATA
    ////////////////////////////////////////////////////////////////

    uint256 constant GAS_FEE = 0.01 ether;

    // Maximum amount for supply, borrow and withdraw
    mapping(mTokenGateway gateway => uint256 amount) maxAmounts;

    function setMaxAmount(
        mTokenGateway gatewayContract,
        uint256 amount
    )
        private
    {
        maxAmounts[gatewayContract] = amount;
    }

    function getMaxAmount(mTokenGateway gatewayContract)
        internal
        view
        returns (uint256 amount)
    {
        amount = maxAmounts[gatewayContract];
    }

    /// DEPLOY PROXY
    ////////////////////////////////////////////////////////////////

    function deployProxy(address implementation) private returns (address) {
        ERC1967Proxy proxy = new ERC1967Proxy(implementation, "");
        return address(proxy);
    }

    /// DEPLOY ROLES
    ////////////////////////////////////////////////////////////////

    /**
     * @notice Deploys a new Roles contract.
     * @param label The label for Forge's vm.label.
     * @param owner The address to set as the contract's owner.
     * @return newRoles The newly deployed Roles contract instance.
     */
    function deployRoles(
        string memory label,
        address owner
    )
        internal
        returns (Roles newRoles)
    {
        newRoles = new Roles(owner);
        vm.label(address(newRoles), label);
    }

    /// DEPLOY BLACKLISTER
    ////////////////////////////////////////////////////////////////

    /**
     * @notice Deploys a new Blacklister contract.
     * @param label The label for Forge's vm.label.
     * @param owner The address to set as the contract's owner.
     * @param rolesContract The Roles contract instance for dependency injection.
     * @return newBlacklister The newly deployed Blacklister contract instance.
     */
    function deployBlacklister(
        string memory label,
        address owner,
        Roles rolesContract
    )
        internal
        returns (Blacklister newBlacklister)
    {
        Blacklister implementation = new Blacklister();
        address proxy = deployProxy(address(implementation));
        newBlacklister = Blacklister(proxy);
        newBlacklister.initialize(payable(owner), address(rolesContract));
        vm.label(address(newBlacklister), label);
    }

    /// DEPLOY RISC0 VERIFIER MOCK
    ////////////////////////////////////////////////////////////////

    /**
     * @notice Deploys a new Risc0VerifierMock contract.
     * @param label The label for Forge's vm.label.
     * @return newMock The newly deployed Risc0VerifierMock contract instance.
     */
    function deployRisc0VerifierMock(string memory label)
        internal
        returns (Risc0VerifierMock newMock)
    {
        newMock = new Risc0VerifierMock();
        vm.label(address(newMock), label);
    }

    /// DEPLOY ZK VERIFIER
    ////////////////////////////////////////////////////////////////

    /**
     * @notice Deploys a new ZkVerifier contract.
     * @param label The label for Forge's vm.label.
     * @param owner The address to set as the contract's owner.
     * @param risc0VerifierContract The Risc0VerifierMock contract instance for dependency injection.
     * @return newZkVerifier The newly deployed ZkVerifier contract instance.
     */
    function deployZkVerifier(
        string memory label,
        address owner,
        Risc0VerifierMock risc0VerifierContract
    )
        internal
        returns (ZkVerifier newZkVerifier)
    {
        bytes32 imageId = keccak256("ZkVerifier");
        newZkVerifier = new ZkVerifier(
            owner, //
            imageId,
            address(risc0VerifierContract)
        );
        vm.label(address(newZkVerifier), label);
    }

    /// DEPLOY ASSET MOCK
    ////////////////////////////////////////////////////////////////

    /**
     * @notice Deploys a new AssetMock contract.
     * @param label The label for Forge's vm.label and the symbol of the asset.
     * @param decimals The decimals of the asset.
     * @return newMock The newly deployed AssetMock contract instance.
     */
    function deployAssetMock(
        string memory label,
        uint8 decimals
    )
        internal
        returns (AssetMock newMock)
    {
        newMock = new AssetMock(label, label, decimals);
        vm.label(address(newMock), label);
    }

    /// DEPLOY GATEWAY
    ////////////////////////////////////////////////////////////////

    /**
     * @notice Deploys a new mTokenGateway contract including its underlying asset.
     * @param label The label for Forge's vm.label and the symbol of the underlying asset.
     * @param owner The address to set as the contract's owner.
     * @param rolesContract The Roles contract instance for dependency injection.
     * @param blacklisterContract The Blacklister contract instance for dependency injection.
     * @param zkVerifierContract The ZkVerifier contract instance for dependency injection.
     * @param gasFee The minimum amount of ETH per supplyOnHost calls.
     * @param maxSupplyAmount The maximum amount per supplyOnHost calls.
     * @return newGateway The newly deployed mTokenGateway contract instance.
     */
    function deployGateway(
        string memory label,
        uint8 underlyingDecimals,
        address owner,
        Roles rolesContract,
        Blacklister blacklisterContract,
        ZkVerifier zkVerifierContract,
        uint256 gasFee,
        uint256 maxSupplyAmount
    )
        internal
        returns (mTokenGateway newGateway)
    {
        AssetMock underlying = deployAssetMock({
            label: label, //
            decimals: underlyingDecimals
        });
        mTokenGateway implementation = new mTokenGateway();
        address proxy = deployProxy(address(implementation));
        newGateway = mTokenGateway(proxy);
        newGateway.initialize(
            payable(owner),
            address(underlying),
            address(rolesContract),
            address(blacklisterContract),
            address(zkVerifierContract)
        );

        vm.prank(owner);
        newGateway.setGasFee(gasFee);

        setMaxAmount(newGateway, maxSupplyAmount);

        vm.label(address(newGateway), string.concat(label, "Gateway"));
    }

    /// DEPLOY BATCH SUBMITTER
    ////////////////////////////////////////////////////////////////

    /**
     * @notice Deploys a new BatchSubmitter contract.
     * @param label The label for Forge's vm.label.
     * @param owner The address to set as the owner.
     * @param rolesContract The Roles contract instance for dependency injection.
     * @param zkVerifierContract The ZkVerifier contract instance for dependency injection.
     * @return newSubmitter The newly deployed BatchSubmitter contract instance.
     */
    function deployBatchSubmitter(
        string memory label,
        address owner,
        Roles rolesContract,
        ZkVerifier zkVerifierContract
    )
        internal
        returns (BatchSubmitter newSubmitter)
    {
        newSubmitter = new BatchSubmitter(
            address(rolesContract), //
            address(zkVerifierContract),
            owner
        );
        vm.label(address(newSubmitter), label);
    }

    /// DEPLOY REWARD DISTRIBUTOR
    ////////////////////////////////////////////////////////////////

    /**
     * @notice Deploys a new RewardDistributor contract.
     * @param label The label for Forge's vm.label.
     * @param owner The address to set as the contract's owner.
     * @return newDistributor The newly deployed RewardDistributor contract instance.
     */
    function deployRewardDistributor(
        string memory label,
        address owner
    )
        internal
        returns (RewardDistributor newDistributor)
    {
        RewardDistributor implementation = new RewardDistributor();
        address proxy = deployProxy(address(implementation));
        newDistributor = RewardDistributor(proxy);
        newDistributor.initialize(owner);
        vm.label(address(newDistributor), label);
    }

    /// DEPLOY OPERATOR
    ////////////////////////////////////////////////////////////////

    /**
     * @notice Deploys a new Operator contract.
     * @param label The label for Forge's vm.label.
     * @param owner The address to set as the owner.
     * @param rolesContract The Roles contract instance for dependency injection.
     * @param blacklisterContract The Blacklister contract instance for dependency injection.
     * @param rewardDistributorContract The RewardDistributor contract instance for dependency injection.
     * @return newOperator The newly deployed Operator contract instance.
     */
    function deployOperator(
        string memory label,
        address owner,
        Roles rolesContract,
        Blacklister blacklisterContract,
        RewardDistributor rewardDistributorContract
    )
        internal
        returns (Operator newOperator)
    {
        Operator implementation = new Operator();
        address proxy = deployProxy(address(implementation));
        newOperator = Operator(proxy);
        newOperator.initialize({
            _rolesOperator: address(rolesContract),
            _blacklistOperator: address(blacklisterContract),
            _rewardDistributor: address(rewardDistributorContract),
            _admin: owner
        });

        vm.prank(owner);
        rewardDistributorContract.setOperator(address(newOperator));

        vm.label(address(newOperator), label);
    }

    /// DEPLOY INTEREST RATE MODEL
    ////////////////////////////////////////////////////////////////

    /**
     * @notice Deploys a new JumpRateModelV4 contract.
     * @param label The label for Forge's vm.label.
     * @param owner The owner of the contract.
     * @param blocksPerYear The estimated number of blocks per year (or seconds, as per implementation).
     * @param baseRatePerYear The base APR, scaled by 1e18.
     * @param multiplierPerYear The rate increase in interest wrt utilization, scaled by 1e18.
     * @param jumpMultiplierPerYear The multiplier per block after utilization point.
     * @param kink The utilization point where the jump multiplier applies.
     * @return newModel The newly deployed JumpRateModelV4 contract instance.
     */
    function deployInterestRateModel(
        string memory label,
        address owner,
        uint256 blocksPerYear,
        uint256 baseRatePerYear,
        uint256 multiplierPerYear,
        uint256 jumpMultiplierPerYear,
        uint256 kink
    )
        internal
        returns (JumpRateModelV4 newModel)
    {
        newModel = new JumpRateModelV4(
            blocksPerYear,
            baseRatePerYear,
            multiplierPerYear,
            jumpMultiplierPerYear,
            kink,
            owner,
            label
        );
        vm.label(address(newModel), label);
    }

    /// DEPLOY MARKET
    ////////////////////////////////////////////////////////////////

    struct DeployMarketParams {
        string symbol;
        uint8 decimals;
        address owner;
        Roles rolesContract;
        Operator operatorContract;
        JumpRateModelV4 interestRateModelContract;
        ZkVerifier zkVerifierContract;
        uint256 initialExchangeRate;
    }

    /**
     * @notice Deploys a new mErc20Host market contract via an ERC1967 proxy.
     * @param params A struct containing all necessary parameters for deployment.
     * @return newMarket The newly deployed mErc20Host contract instance.
     */
    function deployMarket(DeployMarketParams memory params)
        internal
        returns (mErc20Host newMarket)
    {
        AssetMock underlying = deployAssetMock({
            label: string.concat(params.symbol, "MarketUnderlying"),
            decimals: params.decimals
        });
        mErc20Host implementation = new mErc20Host();
        address proxy = deployProxy(address(implementation));
        newMarket = mErc20Host(proxy);
        newMarket.initialize(
            address(underlying),
            address(params.operatorContract),
            address(params.interestRateModelContract),
            params.initialExchangeRate,
            string.concat("m", params.symbol),
            string.concat("m", params.symbol),
            params.decimals,
            payable(params.owner),
            address(params.zkVerifierContract),
            address(params.rolesContract)
        );
        vm.label(address(newMarket), string.concat("m", params.symbol));
    }

    /// DEPLOY CHAINLINK FEED MOCK
    ////////////////////////////////////////////////////////////////

    /**
     * @notice Deploys a new ChainlinkFeedMock contract.
     * @param label The label for Forge's vm.label.
     * @param price The initial price for the feed.
     * @return newFeedMock The newly deployed ChainlinkFeedMock instance.
     */
    function deployChainlinkFeedMock(
        string memory label,
        int256 price
    )
        internal
        returns (ChainlinkFeedMock newFeedMock)
    {
        newFeedMock = new ChainlinkFeedMock(price);
        vm.label(address(newFeedMock), label);
    }

    /// DEPLOY ORACLE
    ////////////////////////////////////////////////////////////////

    struct DeployOracleParams {
        string label;
        Roles rolesContract;
        uint256 stalenessPeriod;
        string[] symbols;
        MixedPriceOracleV4.PriceConfig[] configs;
    }

    /**
     * @notice Deploys a new MixedPriceOracleV4 contract.
     * @param params A struct containing all necessary parameters for deployment.
     * @return newOracle The newly deployed MixedPriceOracleV4 instance.
     */
    function deployOracle(DeployOracleParams memory params)
        internal
        returns (MixedPriceOracleV4 newOracle)
    {
        newOracle = new MixedPriceOracleV4(
            params.symbols,
            params.configs,
            address(params.rolesContract),
            params.stalenessPeriod
        );
        vm.label(address(newOracle), params.label);
    }
}
