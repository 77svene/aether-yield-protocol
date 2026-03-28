// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../core/LienRegistry.sol";
import "./RiskOracle.sol";

/**
 * @title HealthFactor
 * @notice Calculates the risk level of a lien based on collateral value vs debt.
 */
contract HealthFactor {
    LienRegistry public immutable registry;
    RiskOracle public immutable oracle;

    uint256 public constant PRECISION = 1e18;
    uint256 public constant BASIS_POINTS = 10000;

    constructor(address _registry, address _oracle) {
        registry = LienRegistry(_registry);
        oracle = RiskOracle(_oracle);
    }

    /**
     * @notice Returns the health factor of a lien. 
     * @dev Health Factor = (Collateral Value * Max LTV) / Current Debt.
     * A value < 1e18 (1.0 in precision) means the lien is liquidatable.
     */
    function getHealthFactor(bytes32 lienId, uint256 maxLTVBps) external view returns (uint256) {
        (
            ,
            address nftContract,
            ,
            uint256 principal,
            uint256 interestRate,
            uint256 lastUpdate,
            bool active
        ) = registry.liens(lienId);

        require(active, "HealthFactor: Lien not active");

        uint256 floorPrice = oracle.getFloorPrice(nftContract);
        uint256 currentDebt = calculateCurrentDebt(principal, interestRate, lastUpdate);
        
        if (currentDebt == 0) return type(uint256).max;

        // (Floor * LTV_Threshold) / Debt
        // We use 1e18 precision for the result
        uint256 collateralThreshold = (floorPrice * maxLTVBps) / BASIS_POINTS;
        return (collateralThreshold * PRECISION) / currentDebt;
    }

    /**
     * @notice Calculates accrued interest since last update.
     * @dev Simple interest for MVP: Principal * (Rate * Time / Year)
     */
    function calculateCurrentDebt(
        uint256 principal, 
        uint256 rateBps, 
        uint256 lastUpdate
    ) public view returns (uint256) {
        if (lastUpdate == 0 || block.timestamp <= lastUpdate) return principal;
        
        uint256 timeElapsed = block.timestamp - lastUpdate;
        uint256 interest = (principal * rateBps * timeElapsed) / (BASIS_POINTS * 365 days);
        
        return principal + interest;
    }

    /**
     * @notice Helper to check if a lien is liquidatable.
     */
    function isLiquidatable(bytes32 lienId, uint256 maxLTVBps) external view returns (bool) {
        try this.getHealthFactor(lienId, maxLTVBps) returns (uint256 hf) {
            return hf < PRECISION;
        } catch {
            return false;
        }
    }
}