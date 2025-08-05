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

    /// CONTRACTS
    ////////////////////////////////////////////////////////////////

    Roles roles;
    Blacklister blacklister;
    Risc0VerifierMock risc0Mock;
    ZkVerifier zkVerifier;
    mTokenGateway wethGateway;
    mTokenGateway[] gateways;

    /// ADDITIONAL DATA
    ////////////////////////////////////////////////////////////////

    uint256 constant GAS_FEE = 0.01 ether;
    mapping(mTokenGateway gateway => uint256 amount) maxSupplyAmounts;

    /// SETUP
    ////////////////////////////////////////////////////////////////

    function setupGatewayTest() internal {
        setupUsers();
        setupContracts();
        setupGateways();
    }

    function setupUsers() private {
        users = new address[](3);
        users[0] = alice;
        users[1] = bob;
        users[2] = carol;
    }

    function setupContracts() private {
        roles = deployRoles({_name: "Roles", _admin: admin});
        blacklister = deployBlacklister({
            _name: "Blacklister",
            _admin: admin,
            _roles: address(roles)
        });
        risc0Mock = deployRisc0VerifierMock({_name: "Risc0VerifierMock"});
        zkVerifier = deployZkVerifier({
            _name: "ZkVerifier",
            _admin: admin,
            _verifier: address(risc0Mock)
        });
    }

    function setupGateways() private {
        gateways = new mTokenGateway[](3);

        gateways[0] = deployGateway({
            _name: "WETH",
            _decimals: 18,
            _admin: admin,
            _roles: address(roles),
            _blacklister: address(blacklister),
            _zkVerifier: address(zkVerifier),
            _maxSupplyAmount: 10 * 1e18
        });
        wethGateway = gateways[0];
        gateways[1] = deployGateway({
            _name: "USDT",
            _decimals: 6,
            _admin: admin,
            _roles: address(roles),
            _blacklister: address(blacklister),
            _zkVerifier: address(zkVerifier),
            _maxSupplyAmount: 1_000_000 * 1e6
        });
        gateways[2] = deployGateway({
            _name: "USDC",
            _decimals: 6,
            _admin: admin,
            _roles: address(roles),
            _blacklister: address(blacklister),
            _zkVerifier: address(zkVerifier),
            _maxSupplyAmount: 1_000_000 * 1e6
        });
    }

    /// DEPLOY PROXY
    ////////////////////////////////////////////////////////////////

    function deployProxy(address _implementation) private returns (address) {
        ERC1967Proxy proxy = new ERC1967Proxy(_implementation, "");
        return address(proxy);
    }

    /// DEPLOY ROLES
    ////////////////////////////////////////////////////////////////

    function deployRoles(
        string memory _name,
        address _admin
    )
        private
        returns (Roles _roles)
    {
        _roles = new Roles(_admin);
        vm.label(address(_roles), _name);
    }

    /// DEPLOY BLACKLISTER
    ////////////////////////////////////////////////////////////////

    function deployBlacklister(
        string memory _name,
        address _admin,
        address _roles
    )
        internal
        returns (Blacklister _blacklister)
    {
        Blacklister implementation = new Blacklister();
        address proxy = deployProxy(address(implementation));
        _blacklister = Blacklister(proxy);
        _blacklister.initialize(payable(_admin), _roles);
        vm.label(address(_blacklister), _name);
    }

    /// DEPLOY RISC0 VERIFIER MOCK
    ////////////////////////////////////////////////////////////////

    function deployRisc0VerifierMock(string memory _name)
        internal
        returns (Risc0VerifierMock _mock)
    {
        _mock = new Risc0VerifierMock();
        vm.label(address(_mock), _name);
    }

    /// DEPLOY ZK VERIFIER
    ////////////////////////////////////////////////////////////////

    function deployZkVerifier(
        string memory _name,
        address _admin,
        address _verifier
    )
        internal
        returns (ZkVerifier _zkVerifier)
    {
        bytes32 imageId = keccak256("ZkVerifier");
        _zkVerifier = new ZkVerifier(_admin, imageId, _verifier);
        vm.label(address(_zkVerifier), _name);
    }

    /// DEPLOY ASSET MOCK
    ////////////////////////////////////////////////////////////////

    function deployAssetMock(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    )
        internal
        returns (AssetMock _asset)
    {
        _asset = new AssetMock(_name, _symbol, _decimals);
        vm.label(address(_asset), _symbol);
    }

    /// DEPLOY GATEWAY
    ////////////////////////////////////////////////////////////////

    function deployGateway(
        string memory _name,
        uint8 _decimals,
        address _admin,
        address _roles,
        address _blacklister,
        address _zkVerifier,
        uint256 _maxSupplyAmount
    )
        internal
        returns (mTokenGateway _gateway)
    {
        AssetMock underlying = deployAssetMock({
            _name: _name,
            _symbol: _name,
            _decimals: _decimals
        });
        mTokenGateway implementation = new mTokenGateway();
        address proxy = deployProxy(address(implementation));
        _gateway = mTokenGateway(proxy);
        _gateway.initialize(
            payable(_admin),
            address(underlying),
            _roles,
            _blacklister,
            _zkVerifier
        );

        vm.prank(_admin);
        _gateway.setGasFee(GAS_FEE);

        setMaxSupplyAmount(_gateway, _maxSupplyAmount);

        vm.label(address(_gateway), string.concat(_name, "Gateway"));
        vm.label(address(underlying), _name);
    }

    /// UTILITIES
    ////////////////////////////////////////////////////////////////

    function setMaxSupplyAmount(
        mTokenGateway _gateway,
        uint256 _amount
    )
        private
    {
        maxSupplyAmounts[_gateway] = _amount;
    }

    function getMaxSupplyAmount(mTokenGateway _gateway)
        internal
        view
        returns (uint256 _amount)
    {
        _amount = maxSupplyAmounts[_gateway];
    }
}
