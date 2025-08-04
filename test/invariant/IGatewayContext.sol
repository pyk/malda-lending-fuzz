// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {mTokenGateway} from "../../src/mToken/extension/mTokenGateway.sol";
import {AssetMock} from "../mocks/AssetMock.sol";

struct Gateway {
    address owner;
    mTokenGateway mtoken;
    AssetMock underlying;
    uint256 gasFee;
    uint256 maxSupplyAmount;
}

interface IGatewayContext {
    function getRandomUser(uint256 _id) external view returns (address);
    function getRandomGateway(uint256 _id)
        external
        view
        returns (Gateway memory);
}
