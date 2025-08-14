// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

interface Gateway {
    function owner() external view returns (address);
    function withdrawGasFees(address payable receiver) external;
}

contract GatewayWithdrawGasFeesFailed is Test {
    Gateway gateway = Gateway(0xC7Bc6bD45Eb84D594f51cED3c5497E6812C7732f);

    function setUp() external {
        vm.createSelectFork("https://eth.merkle.io");

        // Top up some ETH
        vm.deal(address(gateway), 10 ether);
        assertTrue(address(gateway).balance > 0);
    }

    function test_poc() external {
        address owner = gateway.owner();
        vm.prank(owner);
        gateway.withdrawGasFees(payable(owner));
    }
}
