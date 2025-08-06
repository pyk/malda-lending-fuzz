// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// forgefmt: disable-start
import {Test} from "forge-std/Test.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Roles} from "../../src/Roles.sol";
import {Blacklister} from "../../src/blacklister/Blacklister.sol";
import {Risc0VerifierMock} from "../mocks/Risc0VerifierMock.sol";
import {ZkVerifier} from "../../src/verifier/ZkVerifier.sol";
import {AssetMock} from "../mocks/AssetMock.sol";
import {mTokenGateway} from "../../src/mToken/extension/mTokenGateway.sol";
import {BatchSubmitter} from "../../src/mToken/BatchSubmitter.sol";
// forgefmt: disable-end

/// @title GatewayTest
/// @dev Base contract for unit, fuzz and invariant tests
contract GatewayTest is Test {
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

    /// ADDITIONAL DATA
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

    /// SETUP
    ////////////////////////////////////////////////////////////////

    function setupGatewayTest() internal {
        setupUsers();
        setupContracts();
        setupGateways();
        setupRoles();
    }

    function setupUsers() private {
        users = new address[](3);
        users[0] = alice;
        users[1] = bob;
        users[2] = carol;
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
            maxSupplyAmount: 10 * 1e18,
            gasFee: GAS_FEE
        });
        wethGateway = gateways[0];
        gateways[1] = deployGateway({
            label: "USDT",
            underlyingDecimals: 6,
            owner: admin,
            rolesContract: roles,
            blacklisterContract: blacklister,
            zkVerifierContract: zkVerifier,
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
        vm.stopPrank();
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
        private
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
}
