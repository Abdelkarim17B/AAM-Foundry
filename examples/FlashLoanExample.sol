// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../src/core/SimpleDEX.sol";
import "../src/tokens/interfaces/IERC20Extended.sol";

/**
 * @title FlashLoanExample
 * @dev Example implementation of a flash loan receiver for SimpleDEX
 * @notice This contract demonstrates how to use flash loans for arbitrage opportunities
 */
contract FlashLoanExample is IFlashLoanReceiver {
    SimpleDEX public immutable dex;
    
    event ArbitrageExecuted(
        address indexed token,
        uint256 amount,
        uint256 profit
    );
    
    constructor(address _dex) {
        dex = SimpleDEX(_dex);
    }
    
    /**
     * @dev Execute flash loan callback - implements IFlashLoanReceiver
     * @param token The token being borrowed
     * @param amount The amount borrowed
     * @param fee The fee to be paid
     * @param data Encoded parameters for the operation
     */
    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external {
        require(msg.sender == address(dex), "Unauthorized caller");
        
        // Decode operation parameters
        (bool isArbitrage, bytes memory params) = abi.decode(data, (bool, bytes));
        
        if (isArbitrage) {
            _executeArbitrage(token, amount, fee, params);
        } else {
            // Other flash loan operations can be implemented here
            _executeCustomOperation(token, amount, fee, params);
        }
        
        // Ensure we have enough tokens to repay the loan + fee
        uint256 repayAmount = amount + fee;
        require(
            IERC20Extended(token).balanceOf(address(this)) >= repayAmount,
            "Insufficient balance to repay loan"
        );
        
        // Approve the DEX to take back the borrowed amount + fee
        IERC20Extended(token).approve(address(dex), repayAmount);
    }
    
    /**
     * @dev Execute arbitrage using flash loan
     * @param token The token being arbitraged
     * @param amount The flash loan amount
     * @param fee The flash loan fee
     * @param params Encoded arbitrage parameters
     */
    function _executeArbitrage(
        address token,
        uint256 amount,
        uint256 fee,
        bytes memory params
    ) internal {
        // Decode arbitrage parameters
        (
            bytes32 poolId1,
            bytes32 poolId2,
            address intermediateToken,
            uint256 minProfit
        ) = abi.decode(params, (bytes32, bytes32, address, uint256));
        
        // Step 1: Swap borrowed tokens in first pool
        IERC20Extended(token).approve(address(dex), amount);
        uint256 intermediateAmount = dex.swap(
            poolId1,
            token,
            amount,
            0,
            address(this)
        );
        
        // Step 2: Swap intermediate tokens back in second pool
        IERC20Extended(intermediateToken).approve(address(dex), intermediateAmount);
        uint256 finalAmount = dex.swap(
            poolId2,
            intermediateToken,
            intermediateAmount,
            0,
            address(this)
        );
        
        // Calculate profit
        uint256 totalCost = amount + fee;
        require(finalAmount > totalCost, "Arbitrage not profitable");
        
        uint256 profit = finalAmount - totalCost;
        require(profit >= minProfit, "Profit below minimum threshold");
        
        emit ArbitrageExecuted(token, amount, profit);
    }
    
    /**
     * @dev Execute custom flash loan operation
     * @param token The token being borrowed
     * @param amount The flash loan amount
     * @param fee The flash loan fee
     * @param params Encoded operation parameters
     */
    function _executeCustomOperation(
        address token,
        uint256 amount,
        uint256 fee,
        bytes memory params
    ) internal {
        // Custom flash loan logic can be implemented here
        // For example: liquidations, complex swaps, etc.
        
        // This is a placeholder - implement your custom logic
        // Ensure you maintain enough balance to repay the loan + fee
    }
    
    /**
     * @dev Initiate a flash loan arbitrage
     * @param token The token to borrow
     * @param amount The amount to borrow
     * @param poolId1 First pool for arbitrage
     * @param poolId2 Second pool for arbitrage
     * @param intermediateToken Token used for intermediate swap
     * @param minProfit Minimum profit threshold
     */
    function executeArbitrage(
        address token,
        uint256 amount,
        bytes32 poolId1,
        bytes32 poolId2,
        address intermediateToken,
        uint256 minProfit
    ) external {
        bytes memory params = abi.encode(poolId1, poolId2, intermediateToken, minProfit);
        bytes memory data = abi.encode(true, params);
        
        // Use poolId1 as the pool for the flash loan
        dex.flashLoan(poolId1, token, amount, data);
    }
    
    /**
     * @dev Emergency withdrawal function (only for testing)
     */
    function emergencyWithdraw(address token) external {
        uint256 balance = IERC20Extended(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20Extended(token).transfer(msg.sender, balance);
        }
    }
}
