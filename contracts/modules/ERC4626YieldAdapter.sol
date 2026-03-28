// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title ERC4626YieldAdapter
 * @notice Bridges AetherVault idle liquidity to external yield-bearing ERC4626 vaults.
 * @dev Handles the deposit/withdraw logic to ensure the main vault can always fulfill withdrawals.
 */
contract ERC4626YieldAdapter is Ownable, ReentrancyGuard {
    IERC20 public immutable underlying;
    ERC4626 public immutable targetVault;
    address public immutable aetherVault;

    event YieldDeposited(uint256 amount, uint256 shares);
    event YieldWithdrawn(uint256 amount, uint256 shares);

    modifier onlyVault() {
        require(msg.sender == aetherVault, "YieldAdapter: only AetherVault");
        _;
    }

    constructor(
        address _underlying,
        address _targetVault,
        address _aetherVault
    ) Ownable(msg.sender) {
        require(_underlying != address(0), "Invalid underlying");
        require(_targetVault != address(0), "Invalid target");
        require(_aetherVault != address(0), "Invalid vault");
        
        underlying = IERC20(_underlying);
        targetVault = ERC4626(_targetVault);
        aetherVault = _aetherVault;

        // Infinite approval for the target vault to save gas on future deposits
        underlying.approve(_targetVault, type(uint256).max);
    }

    /**
     * @notice Invests idle funds from AetherVault into the target yield vault.
     * @param amount The amount of underlying tokens to invest.
     */
    function invest(uint256 amount) external onlyVault nonReentrant {
        require(amount > 0, "Amount must be > 0");
        
        // Transfer from AetherVault to this adapter
        bool success = underlying.transferFrom(aetherVault, address(this), amount);
        require(success, "Transfer from vault failed");

        // Deposit into the yield-bearing vault
        uint256 shares = targetVault.deposit(amount, address(this));
        require(shares > 0, "Zero shares minted");

        emit YieldDeposited(amount, shares);
    }

    /**
     * @notice Withdraws funds from the yield vault back to the AetherVault.
     * @param amount The amount of underlying tokens to return.
     */
    function divest(uint256 amount) external onlyVault nonReentrant {
        require(amount > 0, "Amount must be > 0");
        
        // Withdraw from the yield-bearing vault
        // redeem() or withdraw() can be used; withdraw() ensures exact underlying amount
        uint256 shares = targetVault.withdraw(amount, aetherVault, address(this));
        require(shares > 0, "Zero shares burned");

        emit YieldWithdrawn(amount, shares);
    }

    /**
     * @notice Emergency exit: withdraws all shares and sends underlying to AetherVault.
     */
    function emergencyExit() external onlyOwner nonReentrant {
        uint256 totalShares = targetVault.balanceOf(address(this));
        if (totalShares > 0) {
            targetVault.redeem(totalShares, aetherVault, address(this));
        }
    }

    /**
     * @notice Returns the total value managed by this adapter in underlying units.
     */
    function totalValue() external view returns (uint256) {
        return targetVault.convertToAssets(targetVault.balanceOf(address(this)));
    }
}