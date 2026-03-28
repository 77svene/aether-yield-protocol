// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./LienRegistry.sol";

/**
 * @title AetherVault
 * @notice Manages the pool of loanable funds and issues loans against NFT liens.
 * @dev Inherits ERC4626 for yield-bearing liquidity provision.
 */
contract AetherVault is ERC4626, Ownable, ReentrancyGuard {
    LienRegistry public immutable lienRegistry;
    
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public defaultInterestRate = 500; // 5% APR
    uint256 public maxLTV = 6000; // 60% Max Loan-to-Value

    event LoanIssued(address indexed borrower, address nft, uint256 tokenId, uint256 amount);
    event LoanRepaid(address indexed borrower, bytes32 indexed lienId, uint256 amount);

    constructor(
        IERC20 _asset,
        address _lienRegistry,
        string memory _name,
        string memory _symbol
    ) ERC4626(_asset) ERC20(_name, _symbol) Ownable(msg.sender) {
        require(_lienRegistry != address(0), "AetherVault: registry is zero address");
        lienRegistry = LienRegistry(_lienRegistry);
    }

    /**
     * @notice Borrow funds against an NFT.
     * @dev In a production scenario, this would require a ZK-proof or Oracle price check.
     * For the MVP, we assume the caller has already transferred the NFT to a Proxy.
     */
    function borrow(
        address nft,
        uint256 tokenId,
        uint256 amount,
        uint256 floorPrice
    ) external nonReentrant {
        require(amount <= (floorPrice * maxLTV) / BASIS_POINTS, "AetherVault: exceeds max LTV");
        require(amount <= maxWithdraw(address(this)), "AetherVault: insufficient liquidity");

        // Create lien in registry
        lienRegistry.createLien(
            msg.sender,
            nft,
            tokenId,
            amount,
            defaultInterestRate
        );

        // Transfer funds to borrower
        SafeERC20.safeTransfer(IERC20(asset()), msg.sender, amount);

        emit LoanIssued(msg.sender, nft, tokenId, amount);
    }

    /**
     * @notice Repay a loan and release the lien.
     */
    function repay(address nft, uint256 tokenId) external nonReentrant {
        bytes32 lienId = lienRegistry.getLienId(nft, tokenId);
        uint256 debt = lienRegistry.getDebtAmount(lienId);
        
        require(debt > 0, "AetherVault: no active debt");

        // Pull funds from borrower
        SafeERC20.safeTransferFrom(IERC20(asset()), msg.sender, address(this), debt);

        // Resolve lien in registry
        lienRegistry.resolveLien(lienId);

        emit LoanRepaid(msg.sender, lienId, debt);
    }

    function setRiskParams(uint256 _defaultRate, uint256 _maxLTV) external onlyOwner {
        require(_maxLTV <= BASIS_POINTS, "AetherVault: invalid LTV");
        defaultInterestRate = _defaultRate;
        maxLTV = _maxLTV;
    }
}