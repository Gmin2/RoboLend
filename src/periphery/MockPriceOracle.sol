/* SPDX-License-Identifier: MIT */
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockPriceOracle
 * @notice Owner-controlled price oracle for hackathon demo.
 *         Prices use 8 decimals (Chainlink convention).
 */
contract MockPriceOracle is Ownable {
    struct PriceData {
        // USD price with 8 decimals
        uint256 price;
        // Timestamp of last update
        uint256 updatedAt;
        // Whether the market is open (for demo: simulate market hours)
        bool marketOpen;
    }

    // asset address => price data
    mapping(address => PriceData) public prices;

    // Maximum staleness before getPrice reverts (1 hour)
    uint256 public constant MAX_STALENESS = 1 hours;

    // Price decimals (Chainlink convention)
    uint8 public constant DECIMALS = 8;

    event PriceUpdated(address indexed asset, uint256 price);
    event MarketStatusUpdated(address indexed asset, bool open);

    constructor() Ownable(msg.sender) {}

    /**
     * @notice Set the USD price for a single asset
     * @param asset Token address
     * @param priceUsd Price in USD with 8 decimals (e.g., 250_00000000 = $250)
     */
    function setPrice(address asset, uint256 priceUsd) external onlyOwner {
        prices[asset].price = priceUsd;
        prices[asset].updatedAt = block.timestamp;
        if (!prices[asset].marketOpen) {
            prices[asset].marketOpen = true;
        }
        emit PriceUpdated(asset, priceUsd);
    }

    /**
     * @notice Batch-set prices for multiple assets
     * @param assets Array of token addresses
     * @param priceValues Array of prices in USD with 8 decimals
     */
    function setPrices(address[] calldata assets, uint256[] calldata priceValues) external onlyOwner {
        require(assets.length == priceValues.length, "MockPriceOracle: length mismatch");
        for (uint256 i = 0; i < assets.length; i++) {
            prices[assets[i]].price = priceValues[i];
            prices[assets[i]].updatedAt = block.timestamp;
            if (!prices[assets[i]].marketOpen) {
                prices[assets[i]].marketOpen = true;
            }
            emit PriceUpdated(assets[i], priceValues[i]);
        }
    }

    /**
     * @notice Toggle market open/closed for an asset (demo feature)
     * @param asset Token address
     * @param open Whether the market is open
     */
    function setMarketStatus(address asset, bool open) external onlyOwner {
        prices[asset].marketOpen = open;
        emit MarketStatusUpdated(asset, open);
    }

    /**
     * @notice Get the current price for an asset
     * @param asset Token address
     * @return priceUsd Price in USD with 8 decimals
     */
    function getPrice(address asset) external view returns (uint256 priceUsd) {
        PriceData memory data = prices[asset];
        require(data.updatedAt > 0, "MockPriceOracle: price not set");
        require(
            block.timestamp - data.updatedAt <= MAX_STALENESS,
            "MockPriceOracle: stale price"
        );
        return data.price;
    }

    /**
     * @notice Check if an asset's market is currently open
     * @param asset Token address
     * @return Whether the market is open
     */
    function isMarketOpen(address asset) external view returns (bool) {
        return prices[asset].marketOpen;
    }
}
