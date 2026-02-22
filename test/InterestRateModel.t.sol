/* SPDX-License-Identifier: MIT */
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {InterestRateModel} from "../src/periphery/InterestRateModel.sol";
import {WadRayMath} from "../src/libraries/WadRayMath.sol";

contract InterestRateModelTest is Test {
    InterestRateModel irm;

    // Default params: 2% base, 10% slope1, 300% slope2, 80% kink
    uint256 constant BASE   = 0.02e18;
    uint256 constant SLOPE1 = 0.10e18;
    uint256 constant SLOPE2 = 3.00e18;
    uint256 constant KINK   = 0.80e18;

    function setUp() public {
        // Mock ArbSys precompile at 0x64 so arbBlockNumber() works
        vm.mockCall(
            address(0x64),
            abi.encodeWithSignature("arbBlockNumber()"),
            abi.encode(uint256(1_000_000))
        );

        irm = new InterestRateModel(BASE, SLOPE1, SLOPE2, KINK);
    }

    function test_utilizationRate_zeroBorrows() public view {
        uint256 util = irm.utilizationRate(1000e18, 0, 0);
        assertEq(util, 0);
    }

    function test_utilizationRate_50percent() public view {
        // cash=500, borrows=500, reserves=0 => 50%
        uint256 util = irm.utilizationRate(500e18, 500e18, 0);
        assertApproxEqAbs(util, 0.50e18, 1e10);
    }

    function test_utilizationRate_100percent() public view {
        uint256 util = irm.utilizationRate(0, 1000e18, 0);
        assertApproxEqAbs(util, 1e18, 1e10);
    }

    function test_borrowRate_belowKink() public view {
        // At 50% utilization (below 80% kink)
        uint256 rate = irm.getBorrowRate(500e18, 500e18, 0);
        // Expected per-block = (2% + 50% * 10%) / BLOCKS_PER_YEAR = 7% / 126_144_000
        assertTrue(rate > 0);
    }

    function test_borrowRate_aboveKink() public view {
        // At 90% utilization (above 80% kink)
        uint256 rate = irm.getBorrowRate(100e18, 900e18, 0);
        // Should be higher due to jump multiplier
        uint256 rateBelowKink = irm.getBorrowRate(500e18, 500e18, 0);
        assertTrue(rate > rateBelowKink);
    }

    function test_supplyRate_proportional() public view {
        uint256 supplyRate = irm.getSupplyRate(500e18, 500e18, 0, 0.10e18);
        // Supply rate should be positive when there are borrows
        assertTrue(supplyRate > 0);
    }

    function test_blocksPerYear() public view {
        assertEq(irm.BLOCKS_PER_YEAR(), 126_144_000);
    }
}
