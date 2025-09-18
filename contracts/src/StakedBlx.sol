// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title StakedBLX - Liquid Staking Token
 * @dev Represents staked BLX tokens in liquid staking system
 */
contract StakedBLX is ERC20, Ownable {
    constructor() ERC20("Staked BLX", "stBLX") {}

    /// @dev Mint stBLX tokens (restricted to owner/staking contract)
    function mint(address account, uint256 amount) external onlyOwner {
        _mint(account, amount);
    }

    /// @dev Burn stBLX tokens when redeeming
    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }
}