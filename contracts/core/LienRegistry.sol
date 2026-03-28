// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title LienRegistry
 * @notice Tracks debt and liquidation rights against specific NFT assets.
 * @dev Source of truth for encumbered NFTs with interest-bearing debt logic.
 */
contract LienRegistry is Ownable {
    struct Lien {
        address borrower;
        address nftContract;
        uint256 tokenId;
        uint256 principal;
        uint256 interestRate; // Annual rate in basis points (1% = 100)
        uint256 lastUpdateTimestamp;
        bool active;
    }

    // Mapping from LienID (keccak256(abi.encode(nftContract, tokenId))) to Lien details
    mapping(bytes32 => Lien) public liens;
    
    // Authorized vaults that can create/resolve liens
    mapping(address => bool) public authorizedVaults;

    event LienCreated(bytes32 indexed lienId, address indexed borrower, address nft, uint256 tokenId, uint256 principal);
    event LienResolved(bytes32 indexed lienId, uint256 finalRepayment);
    event VaultStatusUpdated(address indexed vault, bool status);

    constructor() Ownable(msg.sender) {}

    modifier onlyVault() {
        require(authorizedVaults[msg.sender], "LienRegistry: caller is not an authorized vault");
        _;
    }

    function setVaultStatus(address vault, bool status) external onlyOwner {
        authorizedVaults[vault] = status;
        emit VaultStatusUpdated(vault, status);
    }

    /**
     * @notice Generates a unique ID for a lien using abi.encode to prevent collisions.
     */
    function getLienId(address nftContract, uint256 tokenId) public pure returns (bytes32) {
        return keccak256(abi.encode(nftContract, tokenId));
    }

    /**
     * @notice Registers a new lien. Only callable by authorized vaults.
     */
    function createLien(
        address borrower,
        address nftContract,
        uint256 tokenId,
        uint256 principal,
        uint256 interestRate
    ) external onlyVault returns (bytes32 lienId) {
        lienId = getLienId(nftContract, tokenId);
        require(!liens[lienId].active, "LienRegistry: lien already exists");

        liens[lienId] = Lien({
            borrower: borrower,
            nftContract: nftContract,
            tokenId: tokenId,
            principal: principal,
            interestRate: interestRate,
            lastUpdateTimestamp: block.timestamp,
            active: true
        });

        emit LienCreated(lienId, borrower, nftContract, tokenId, principal);
    }

    /**
     * @notice Calculates current debt including accrued interest.
     */
    function getCurrentDebt(bytes32 lienId) public view returns (uint256) {
        Lien storage lien = liens[lienId];
        if (!lien.active) return 0;

        uint256 timeElapsed = block.timestamp - lien.lastUpdateTimestamp;
        if (timeElapsed == 0) return lien.principal;

        // Simple interest: Principal + (Principal * Rate * Time / (SecondsPerYear * 10000))
        uint256 interest = (lien.principal * lien.interestRate * timeElapsed) / (365 days * 10000);
        return lien.principal + interest;
    }

    /**
     * @notice Resolves a lien. Vault must prove full repayment or liquidation.
     */
    function resolveLien(bytes32 lienId) external onlyVault {
        require(liens[lienId].active, "LienRegistry: lien not active");
        
        uint256 finalDebt = getCurrentDebt(lienId);
        liens[lienId].active = false;
        
        emit LienResolved(lienId, finalDebt);
    }

    function isLienActive(address nftContract, uint256 tokenId) external view returns (bool) {
        return liens[getLienId(nftContract, tokenId)].active;
    }
}