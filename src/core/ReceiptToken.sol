/* SPDX-License-Identifier: MIT */
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ReceiptToken
 * @notice ERC-20 yield-bearing receipt token (e.g. rhTSLA, rhAMZN).
 *         Only the parent AssetVault (owner) can mint and burn.
 */
contract ReceiptToken is ERC20, Ownable {
    uint8 private _decimals;

    /**
     * @param name_     Token name (e.g. "Robinhood TSLA")
     * @param symbol_   Token symbol (e.g. "rhTSLA")
     * @param decimals_ Must match the underlying token decimals
     * @param vault     The AssetVault that owns this receipt token
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address vault
    ) ERC20(name_, symbol_) Ownable(vault) {
        _decimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /**
     * @notice Mint receipt tokens. Only callable by the vault.
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /**
     * @notice Burn receipt tokens. Only callable by the vault.
     */
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}
