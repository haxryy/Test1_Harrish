// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockERC20 - Test Token Contract
 * @dev Simple ERC20 token for testing purposes with public minting
 */
contract MockERC20 is ERC20 {
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply
    ) ERC20(name_, symbol_) {
        if (initialSupply > 0) {
            _mint(_msgSender(), initialSupply);
        }
    }

    /// @dev Mint tokens to any address (for testing only)
    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }
}