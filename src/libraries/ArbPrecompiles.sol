/* SPDX-License-Identifier: MIT */
pragma solidity ^0.8.20;

import {ArbSys} from "@arbitrum/nitro-contracts/src/precompiles/ArbSys.sol";
import {ArbGasInfo} from "@arbitrum/nitro-contracts/src/precompiles/ArbGasInfo.sol";

/**
 * @title ArbPrecompiles
 * @notice Wrapper around Arbitrum precompiles (ArbSys + ArbGasInfo)
 *         deployed at fixed addresses on every Arbitrum Orbit chain.
 */
library ArbPrecompiles {
    ArbSys internal constant ARB_SYS = ArbSys(address(0x64));
    ArbGasInfo internal constant ARB_GAS_INFO = ArbGasInfo(address(0x6C));

    // Robinhood Chain Testnet chain ID
    uint256 internal constant ROBINHOOD_CHAIN_ID = 46630;

    /**
     * @notice Returns the L2 block number from ArbSys.
     *         On Orbit chains this ticks every ~250ms, much more granular
     *         than block.number which may return the L1 block.
     */
    function arbBlockNumber() internal view returns (uint256) {
        return ARB_SYS.arbBlockNumber();
    }

    /**
     * @notice Returns the chain ID reported by the ArbSys precompile.
     */
    function arbChainID() internal view returns (uint256) {
        return ARB_SYS.arbChainID();
    }

    /**
     * @notice Minimum gas price on L2 (wei).
     */
    function getMinimumGasPrice() internal view returns (uint256) {
        return ARB_GAS_INFO.getMinimumGasPrice();
    }

    /**
     * @notice ArbOS estimate of the current L1 base fee (wei).
     */
    function getL1BaseFeeEstimate() internal view returns (uint256) {
        return ARB_GAS_INFO.getL1BaseFeeEstimate();
    }

    /**
     * @notice Reverts unless we are running on Robinhood Chain (ID 46630).
     */
    function verifyChain() internal view {
        require(
            ARB_SYS.arbChainID() == ROBINHOOD_CHAIN_ID,
            "ArbPrecompiles: not Robinhood Chain"
        );
    }
}
