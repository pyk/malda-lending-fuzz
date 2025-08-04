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
import {GatewayHandler} from "./handlers/GatewayHandler.sol";
import {IGatewayContext, Gateway} from "./IGatewayContext.sol";
// forgefmt: disable-end

contract GatewayInvariantTest is Test, IGatewayContext {
    address admin = makeAddr("admin");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address carol = makeAddr("carol");

    address[] users;

    Roles roles;
    Blacklister blacklister;
    Risc0VerifierMock risc0Verifier;
    ZkVerifier zkVerifier;
    GatewayHandler handler;

    Gateway[3] gateways;

    function setUp() external {
        setupUsers();

        roles = deployRoles({
            _name: "Roles", //
            _admin: admin
        });

        blacklister = deployBlacklister({
            _name: "Blacklister",
            _admin: admin,
            _roles: address(roles)
        });

        risc0Verifier = deployRisc0VerifierMock({
            _name: "Risc0VerifierMock" //
        });

        zkVerifier = deployZkVerifier({
            _name: "ZkVerifier",
            _admin: admin,
            _verifier: address(risc0Verifier)
        });

        gateways[0] = deployGateway({
            _name: "WETH", //
            _decimals: 18,
            _admin: admin,
            _roles: address(roles),
            _blacklister: address(blacklister),
            _zkVerifier: address(zkVerifier),
            _maxSupplyAmount: 10 * 1e18
        });
        gateways[1] = deployGateway({
            _name: "USDT", //
            _decimals: 6,
            _admin: admin,
            _roles: address(roles),
            _blacklister: address(blacklister),
            _zkVerifier: address(zkVerifier),
            _maxSupplyAmount: 1_000_000 * 1e6
        });
        gateways[2] = deployGateway({
            _name: "USDC", //
            _decimals: 6,
            _admin: admin,
            _roles: address(roles),
            _blacklister: address(blacklister),
            _zkVerifier: address(zkVerifier),
            _maxSupplyAmount: 1_000_000 * 1e6
        });

        handler = new GatewayHandler(address(this));

        targetContract(address(handler));
    }

    function setupUsers() internal {
        users = new address[](3);
        users[0] = alice;
        users[1] = bob;
        users[2] = carol;
    }

    function getRandomUser(uint256 _id) public view returns (address _user) {
        _user = users[bound(_id, 0, users.length - 1)];
    }

    function getRandomGateway(uint256 _id)
        public
        view
        returns (Gateway memory _gateway)
    {
        _gateway = gateways[bound(_id, 0, gateways.length - 1)];
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
        uint8 _decimals,
        address _admin,
        address _roles,
        address _blacklister,
        address _zkVerifier,
        uint256 _maxSupplyAmount
    )
        internal
        returns (Gateway memory _gateway)
    {
        _gateway.gasFee = 0.01 ether;
        _gateway.owner = _admin;
        _gateway.maxSupplyAmount = _maxSupplyAmount;

        AssetMock underlying = deployAsset({
            _name: _name, //
            _symbol: _name,
            _decimals: _decimals
        });
        mTokenGateway implementation = new mTokenGateway();
        address proxy = deployProxy(address(implementation));
        _gateway.mtoken = mTokenGateway(proxy);
        _gateway.mtoken.initialize(
            payable(_admin), //
            address(underlying),
            _roles,
            _blacklister,
            _zkVerifier
        );
        _gateway.underlying = underlying;

        vm.prank(_admin);
        _gateway.mtoken.setGasFee(_gateway.gasFee);

        vm.label(address(_gateway.mtoken), string.concat(_name, "Gateway"));
        vm.label(address(underlying), _name);
    }

    function assert_getProof(
        mTokenGateway _mtoken,
        address[] memory _users
    )
        internal
        view
    {
        uint256 actorCount = _users.length;
        for (uint256 i = 0; i < actorCount; i++) {
            address user = _users[i];
            (uint256 actualAmountIn, uint256 actualAmountOut) =
                handler.getAmounts(address(_mtoken), user);
            (uint256 amountIn, uint256 amountOut) =
                _mtoken.getProofData(user, 0);
            assertEq(
                actualAmountIn, //
                amountIn,
                "getProof amountIn is incorrect"
            );
            assertEq(
                actualAmountOut, //
                amountOut,
                "getProof amountOut is incorrect"
            );
        }
    }

    function invariant_getProof_correct() external view {
        uint256 gatewayCount = gateways.length;
        for (uint256 i = 0; i < gatewayCount; i++) {
            Gateway memory gateway = gateways[i];
            assert_getProof({_mtoken: gateway.mtoken, _users: users});
        }
    }

    function test_withdrawGasFees_access_control(
        uint256 _gatewayId,
        address _user
    )
        external
    {
        Gateway memory gateway = getRandomGateway(_gatewayId);
        vm.expectRevert();
        vm.prank(_user);
        gateway.mtoken.withdrawGasFees(payable(address(this)));
    }

    function test_extractForRebalancing_accress_control(
        uint256 _gatewayId,
        address _user
    )
        external
    {
        Gateway memory gateway = getRandomGateway(_gatewayId);
        vm.expectRevert();
        vm.prank(_user);
        gateway.mtoken.extractForRebalancing(0);
    }
}
