// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// forgefmt: disable-start
import {Test} from "forge-std/Test.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AssetMock} from "../mocks/AssetMock.sol";
import {Roles} from "../../src/Roles.sol";
import {Blacklister} from "../../src/blacklister/Blacklister.sol";
import {ZkVerifier} from "../../src/verifier/ZkVerifier.sol";
import {Risc0VerifierMock} from "../mocks/Risc0VerifierMock.sol";
import {mTokenGateway} from "../../src/mToken/extension/mTokenGateway.sol";
// forgefmt: disable-end

contract GatewayInvariantTest is Test {
    address admin = makeAddr("admin");

    AssetMock underlying;
    Roles roles;
    Blacklister blacklister;
    Risc0VerifierMock risc0Verifier;
    ZkVerifier zkVerifier;
    mTokenGateway gateway;

    function setUp() external {
        underlying = deployAsset({
            _name: "Wrapped ETH", //
            _symbol: "WETH",
            _decimals: 18
        });

        roles = deployRoles({
            _name: "EthereumRoles", //
            _admin: admin
        });

        blacklister = deployBlacklister({
            _name: "EthereumBlacklister",
            _admin: admin,
            _roles: address(roles)
        });

        risc0Verifier = deployRisc0VerifierMock({
            _name: "EthereumRisc0VerifierMock" //
        });

        zkVerifier = deployZkVerifier({
            _name: "EthereumZkVerifier",
            _admin: admin,
            _verifier: address(risc0Verifier)
        });

        gateway = deployGateway({
            _name: "WETHGateway", //
            _admin: admin,
            _underlying: address(underlying),
            _roles: address(roles),
            _blacklister: address(blacklister),
            _zkVerifier: address(zkVerifier)
        });
    }

    function deployProxy(address _implementation) internal returns (address) {
        ERC1967Proxy proxy = new ERC1967Proxy(_implementation, "");
        return address(proxy);
    }

    function deployAsset(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    )
        internal
        returns (AssetMock asset)
    {
        asset = new AssetMock(_name, _symbol, _decimals);
        vm.label(address(asset), _symbol);
    }

    function deployRoles(
        string memory _name,
        address _admin
    )
        internal
        returns (Roles _roles)
    {
        _roles = new Roles(_admin);
        vm.label(address(_roles), _name);
    }

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

    function deployRisc0VerifierMock(string memory _name)
        internal
        returns (Risc0VerifierMock _mock)
    {
        _mock = new Risc0VerifierMock();
        vm.label(address(_mock), _name);
    }

    function deployZkVerifier(
        string memory _name,
        address _admin,
        address _verifier
    )
        internal
        returns (ZkVerifier _zkVerifier)
    {
        bytes32 imageId = keccak256("ZkVerifier");
        _zkVerifier = new ZkVerifier(
            _admin, //
            imageId,
            _verifier
        );
        vm.label(address(_zkVerifier), _name);
    }

    function deployGateway(
        string memory _name,
        address _admin,
        address _underlying,
        address _roles,
        address _blacklister,
        address _zkVerifier
    )
        internal
        returns (mTokenGateway _gateway)
    {
        mTokenGateway implementation = new mTokenGateway();
        address proxy = deployProxy(address(implementation));
        _gateway = mTokenGateway(proxy);
        _gateway.initialize(
            payable(_admin), //
            _underlying,
            _roles,
            _blacklister,
            _zkVerifier
        );
        vm.label(address(_gateway), _name);
    }

    function invariant_a() external {
        assertTrue(true, "OK");
    }
}
