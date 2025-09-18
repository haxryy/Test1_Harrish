// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title BLXToken - BLUME Ecosystem Token
 * @dev ERC20 token with minting, burning, pausable, and access control features
 */

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BLXToken is ERC20, ERC20Burnable, Pausable, AccessControl, Ownable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply
    ) ERC20(name_, symbol_) {
        // Grant admin and minter roles to deployer
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());

        // Set deployer as owner
        transferOwnership(_msgSender());

        // Mint initial supply to deployer
        if (initialSupply > 0) {
            _mint(_msgSender(), initialSupply);
        }
    }

    // ==================== MINTING FUNCTIONS ====================

    /// @dev Mint tokens to specified address (restricted to MINTER_ROLE)
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        require(to != address(0), "mint to zero");
        _mint(to, amount);
    }

    // ==================== ADMIN FUNCTIONS ====================

    /// @dev Pause all token transfers (admin only)
    function pause() external onlyOwner {
        _pause();
    }

    /// @dev Unpause all token transfers (admin only)
    function unpause() external onlyOwner {
        _unpause();
    }
}
