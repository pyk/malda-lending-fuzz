// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// forgefmt: disable-start
import {
    MaldaTest,
    Roles,
    Rebalancer,
    AccrossBridge,
    EverclearBridge
} from "../MaldaTest.sol";
// forgefmt: disable-end

contract RebalancerTest is MaldaTest {
    Roles roles;
    Rebalancer rebalancer;
    AccrossBridge acrossBridge;
    EverclearBridge everclearBridge;

    function setUp() external {
        roles = deployRoles({label: "Roles", owner: admin});
        address saveAddress = makeAddr("saveAddress");

        rebalancer = deployRebalancer({
            label: "Rebalancer",
            rolesContract: roles,
            saveAddress: saveAddress
        });

        address mockAcrossSpokePool = makeAddr("AcrossSpokePool");
        acrossBridge = deployAcrossBridge({
            label: "AcrossBridge",
            rolesContract: roles,
            spokePoolAddress: mockAcrossSpokePool
        });

        address mockEverclearFeeAdapter = makeAddr("EverclearFeeAdapter");
        everclearBridge = deployEverclearBridge({
            label: "EverclearBridge",
            rolesContract: roles,
            feeAdapterAddress: mockEverclearFeeAdapter
        });

        vm.startPrank(admin);
        roles.allowFor(address(rebalancer), roles.REBALANCER(), true);
        vm.stopPrank();
    }
}
