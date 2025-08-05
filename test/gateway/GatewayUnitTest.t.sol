// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// forgefmt: disable-start
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {GatewayTest} from "./GatewayTest.sol";
// forgefmt: disable-end

/// @custom:command forge test --match-contract GatewayUnitTest
contract GatewayUnitTest is GatewayTest {
    function setUp() external {
        setupGatewayTest();
    }

    function test_initialize() external {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        wethGateway.initialize(
            payable(admin),
            makeAddr("underlying"),
            makeAddr("roles"),
            makeAddr("blacklister"),
            makeAddr("zkVerifier")
        );
    }
}
