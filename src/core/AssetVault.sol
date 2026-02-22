/* SPDX-License-Identifier: MIT */
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ReceiptToken} from "./ReceiptToken.sol";
import {WadRayMath} from "../libraries/WadRayMath.sol";
import {ArbPrecompiles} from "../libraries/ArbPrecompiles.sol";

/**
 * @title AssetVault
 * @notice Per-token vault that accepts deposits, mints receipt tokens,
 *         and tracks a supply index for interest accrual.
 *         One vault per asset (TSLA, AMZN, PLTR, NFLX, AMD, WETH).
 */
contract AssetVault is ReentrancyGuard {
    using SafeERC20 for IERC20;
    using WadRayMath for uint256;

    // The underlying ERC-20 token this vault holds
    IERC20 public immutable underlying;

    // The receipt token minted to depositors
    ReceiptToken public immutable receiptToken;

    // Supply index in RAY — starts at 1 RAY
    uint256 public supplyIndex;

    // Last L2 block at which interest was accrued
    uint256 public lastUpdateBlock;

    // The LendingPool that can call privileged functions
    address public lendingPool;

    // Whether the lending pool address has been set (one-time)
    bool public lendingPoolSet;

    event Deposited(address indexed user, uint256 underlyingAmount, uint256 receiptAmount);
    event Withdrawn(address indexed user, uint256 receiptAmount, uint256 underlyingAmount);
    event InterestAccrued(uint256 interestEarned, uint256 newSupplyIndex);
    event LendingPoolLinked(address indexed pool);

    modifier onlyLendingPool() {
        require(msg.sender == lendingPool, "AssetVault: caller is not LendingPool");
        _;
    }

    /**
     * @param _underlying   The underlying ERC-20 token
     * @param _name         Receipt token name (e.g. "Robinhood TSLA")
     * @param _symbol       Receipt token symbol (e.g. "rhTSLA")
     * @param _decimals     Decimals matching the underlying
     */
    constructor(
        address _underlying,
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) {
        underlying = IERC20(_underlying);
        receiptToken = new ReceiptToken(_name, _symbol, _decimals, address(this));
        supplyIndex = WadRayMath.RAY;
        lastUpdateBlock = ArbPrecompiles.arbBlockNumber();
    }

    /**
     * @notice One-time link to the LendingPool contract
     * @param _lendingPool Address of the deployed LendingPool
     */
    function setLendingPool(address _lendingPool) external {
        require(!lendingPoolSet, "AssetVault: pool already set");
        require(_lendingPool != address(0), "AssetVault: zero address");
        lendingPool = _lendingPool;
        lendingPoolSet = true;
        emit LendingPoolLinked(_lendingPool);
    }

    /**
     * @notice Deposit underlying tokens and receive receipt tokens
     * @param amount     Amount of underlying to deposit
     * @param onBehalfOf Address that receives the receipt tokens
     * @return receiptAmount Number of receipt tokens minted
     */
    function deposit(
        uint256 amount,
        address onBehalfOf
    ) external nonReentrant onlyLendingPool returns (uint256 receiptAmount) {
        require(amount > 0, "AssetVault: zero deposit");

        // Convert underlying to receipt using current supplyIndex
        receiptAmount = (amount * WadRayMath.RAY) / supplyIndex;

        underlying.safeTransferFrom(msg.sender, address(this), amount);
        receiptToken.mint(onBehalfOf, receiptAmount);

        emit Deposited(onBehalfOf, amount, receiptAmount);
    }

    /**
     * @notice Burn receipt tokens and withdraw underlying
     * @param receiptAmount Number of receipt tokens to redeem
     * @param to            Address that receives the underlying
     * @return underlyingAmount Number of underlying tokens returned
     */
    function withdraw(
        uint256 receiptAmount,
        address to
    ) external nonReentrant onlyLendingPool returns (uint256 underlyingAmount) {
        require(receiptAmount > 0, "AssetVault: zero withdrawal");

        underlyingAmount = receiptAmount.rayMul(supplyIndex);

        // Receipt tokens are held by the LendingPool (msg.sender)
        receiptToken.burn(msg.sender, receiptAmount);
        underlying.safeTransfer(to, underlyingAmount);

        emit Withdrawn(to, receiptAmount, underlyingAmount);
    }

    /**
     * @notice Accrue interest earned — increases the supply index
     * @param interestEarned Amount of underlying earned as interest
     */
    function accrueInterest(uint256 interestEarned) external onlyLendingPool {
        if (interestEarned == 0) return;

        uint256 totalReceipts = receiptToken.totalSupply();
        if (totalReceipts == 0) return;

        /**
         * newIndex = oldIndex * (1 + interestEarned / totalUnderlying)
         * where totalUnderlying = totalReceipts * oldIndex / RAY
         */
        uint256 underlyingTotal = totalReceipts.rayMul(supplyIndex);
        uint256 indexIncrease = (interestEarned * WadRayMath.RAY) / underlyingTotal;
        supplyIndex = supplyIndex + supplyIndex.rayMul(indexIncrease);

        lastUpdateBlock = ArbPrecompiles.arbBlockNumber();

        emit InterestAccrued(interestEarned, supplyIndex);
    }

    /**
     * @notice Get the underlying-token balance for a user (receipt * index)
     * @param user Address to query
     * @return The equivalent underlying balance
     */
    function balanceOfUnderlying(address user) external view returns (uint256) {
        return receiptToken.balanceOf(user).rayMul(supplyIndex);
    }

    /**
     * @notice Total underlying held in this vault
     */
    function totalUnderlying() external view returns (uint256) {
        return underlying.balanceOf(address(this));
    }
}
