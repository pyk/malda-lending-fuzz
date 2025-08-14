// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

interface Gateway {
    function owner() external view returns (address);
    function withdrawGasFees(address payable receiver) external;
}

contract GatewayWithdrawGasFeesFailed is Test {
    Gateway gateway = Gateway(0xACCFD6C3099Bac60cc8B99cAB6d5f1A107355316);

    function setUp() external {
        vm.createSelectFork("https://eth.merkle.io", 23137820);

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
