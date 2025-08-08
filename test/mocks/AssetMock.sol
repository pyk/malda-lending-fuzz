// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract AssetMock is ERC20 {
    uint8 tokenDecimals;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    )
        ERC20(_name, _symbol)
    {
        tokenDecimals = _decimals;
    }

    function decimals() public view override returns (uint8) {
        return tokenDecimals;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    //*============================================================
    //* WETH Support
    //*============================================================

    // Events
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    // Deposit ETH and mint WETH
    function deposit() public payable {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    // Burn WETH and withdraw ETH
    function withdraw(uint256 wad) public {
        require(balanceOf(msg.sender) >= wad, "WETH: insufficient balance");
        _burn(msg.sender, wad);
        payable(msg.sender).transfer(wad);
        emit Withdrawal(msg.sender, wad);
    }

    // Allow contract to receive ETH
    receive() external payable {
        deposit();
    }

    // Fallback function
    fallback() external payable {
        deposit();
    }
}
