// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// forgefmt: disable-start
import {
    MaldaTest,
    Roles,
    Rebalancer,
    AccrossBridge,
    EverclearBridge,
    mTokenGateway,
    AssetMock
} from "../MaldaTest.sol";
// forgefmt: disable-end

//
// https://docs.across.to/reference/contract-addresses/mainnet-chain-id-1
// https://docs.everclear.org/resources/contracts/mainnet
contract RebalancerTest is MaldaTest {
    mTokenGateway gateway =
        mTokenGateway(0xC7Bc6bD45Eb84D594f51cED3c5497E6812C7732f);
    AssetMock asset;
    Roles roles = Roles(0x1211d07F0EBeA8994F23EC26e1e512929FC8Ab08);
    Rebalancer rebalancer;
    AccrossBridge acrossBridge;
    EverclearBridge everclearBridge;

    function setUp() external {
        vm.createSelectFork("https://eth.merkle.io", 23138311);

        vm.label(address(gateway), "Gateway");
        vm.label(address(roles), "Roles");

        asset = AssetMock(payable(gateway.underlying()));
        vm.label(address(asset), "Asset");

        address saveAddress = makeAddr("saveAddress");
        rebalancer = deployRebalancer({
            label: "Rebalancer",
            rolesContract: roles,
            saveAddress: saveAddress
        });

        address spokePool = 0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5;
        acrossBridge = deployAcrossBridge({
            label: "AcrossBridge",
            rolesContract: roles,
            spokePoolAddress: spokePool
        });

        address feeAdapter = 0x15a7cA97D1ed168fB34a4055CEFa2E2f9Bdb6C75;
        everclearBridge = deployEverclearBridge({
            label: "EverclearBridge",
            rolesContract: roles,
            feeAdapterAddress: feeAdapter
        });

        vm.startPrank(roles.owner());
        roles.allowFor(address(rebalancer), roles.REBALANCER(), true);
        roles.allowFor(address(this), roles.REBALANCER_EOA(), true);
        roles.allowFor(address(this), roles.GUARDIAN_BRIDGE(), true);
        vm.stopPrank();

        rebalancer.setWhitelistedBridgeStatus(address(acrossBridge), true);
        rebalancer.setWhitelistedBridgeStatus(address(everclearBridge), true);
        rebalancer.setWhitelistedDestination(LINEA_CHAIN_ID, true);
        rebalancer.setWhitelistedDestination(BASE_CHAIN_ID, true);
        address[] memory allowList = new address[](1);
        allowList[0] = address(gateway);
        rebalancer.setAllowList(allowList, true);
    }

    function createAcrossBridgeMessage(
        uint256 inputAmount,
        uint256 outputAmount,
        address relayer,
        uint32 deadline,
        uint32 exclusivityDeadline
    )
        public
        pure
        returns (bytes memory message)
    {
        return abi.encode(
            inputAmount, outputAmount, relayer, deadline, exclusivityDeadline
        );
    }
}
