// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title RiskOracle
 * @notice Aggregates floor price data for NFT collections with safety checks.
 * @dev Implements heartbeat validation and deviation thresholds to prevent stale or manipulated data.
 */
contract RiskOracle is Ownable {
    struct PriceData {
        uint256 floorPrice;
        uint256 lastUpdated;
        bool exists;
    }

    // Collection address => PriceData
    mapping(address => PriceData) public collectionPrices;
    
    // Authorized price updaters (e.g., Chainlink Nodes or ZK-Relayers)
    mapping(address => bool) public isUpdater;

    // Safety Parameters
    uint256 public constant MAX_PRICE_DEVIATION = 2000; // 20% in basis points
    uint256 public constant HEARTBEAT_THRESHOLD = 3600; // 1 hour max staleness
    uint256 public constant BASIS_POINTS = 10000;

    event PriceUpdated(address indexed collection, uint256 price, uint256 timestamp);
    event UpdaterStatusChanged(address indexed updater, bool status);

    constructor() Ownable(msg.sender) {
        isUpdater[msg.sender] = true;
    }

    modifier onlyUpdater() {
        require(isUpdater[msg.sender], "RiskOracle: caller is not an authorized updater");
        _;
    }

    function setUpdater(address updater, bool status) external onlyOwner {
        require(updater != address(0), "RiskOracle: zero address");
        isUpdater[updater] = status;
        emit UpdaterStatusChanged(updater, status);
    }

    /**
     * @notice Updates the floor price with safety checks.
     * @param collection The NFT contract address.
     * @param newPrice The new floor price in wei.
     */
    function updatePrice(address collection, uint256 newPrice) external onlyUpdater {
        require(collection != address(0), "RiskOracle: zero address");
        require(newPrice > 0, "RiskOracle: price must be positive");

        PriceData storage data = collectionPrices[collection];

        if (data.exists) {
            // Deviation Check: Prevent sudden price swings (e.g. flash loan attacks)
            uint256 oldPrice = data.floorPrice;
            uint256 diff = newPrice > oldPrice ? newPrice - oldPrice : oldPrice - newPrice;
            require(
                (diff * BASIS_POINTS) / oldPrice <= MAX_PRICE_DEVIATION,
                "RiskOracle: price deviation too high"
            );
        }

        data.floorPrice = newPrice;
        data.lastUpdated = block.timestamp;
        data.exists = true;

        emit PriceUpdated(collection, newPrice, block.timestamp);
    }

    /**
     * @notice Returns the floor price if it is not stale.
     */
    function getPrice(address collection) external view returns (uint256) {
        PriceData memory data = collectionPrices[collection];
        require(data.exists, "RiskOracle: price not found");
        require(
            block.timestamp - data.lastUpdated <= HEARTBEAT_THRESHOLD,
            "RiskOracle: price is stale"
        );
        return data.floorPrice;
    }
}