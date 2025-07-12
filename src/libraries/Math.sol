// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Math
 * @notice Mathematical utility functions for the DEX
 * @dev Provides additional math operations not available in OpenZeppelin's Math library
 */
library Math {
    /**
     * @notice Calculates the square root of a number using the Babylonian method
     * @param x The number to calculate square root for
     * @return The square root of x
     */
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        
        // Set the initial guess to the average of x and 1
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        
        // Iterate until convergence
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        
        return y;
    }

    /**
     * @notice Calculates x^y using exponentiation by squaring
     * @param x Base
     * @param y Exponent
     * @return Result of x^y
     */
    function pow(uint256 x, uint256 y) internal pure returns (uint256) {
        if (y == 0) return 1;
        if (x == 0) return 0;
        
        uint256 result = 1;
        uint256 base = x;
        
        while (y > 0) {
            if (y & 1 == 1) {
                result = result * base;
            }
            base = base * base;
            y >>= 1;
        }
        
        return result;
    }

    /**
     * @notice Calculates the minimum of two numbers
     * @param a First number
     * @param b Second number
     * @return The smaller of the two numbers
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @notice Calculates the maximum of two numbers
     * @param a First number
     * @param b Second number
     * @return The larger of the two numbers
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @notice Calculates the absolute difference between two numbers
     * @param a First number
     * @param b Second number
     * @return The absolute difference
     */
    function abs(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : b - a;
    }

    /**
     * @notice Calculates percentage with specified decimal places
     * @param value The value to calculate percentage of
     * @param percent The percentage (with decimals)
     * @param decimals Number of decimal places in percentage
     * @return The calculated percentage value
     */
    function percentage(uint256 value, uint256 percent, uint256 decimals) internal pure returns (uint256) {
        return (value * percent) / (10 ** decimals);
    }

    /**
     * @notice Calculates the geometric mean of two numbers
     * @param a First number
     * @param b Second number
     * @return The geometric mean
     */
    function geometricMean(uint256 a, uint256 b) internal pure returns (uint256) {
        return sqrt(a * b);
    }

    /**
     * @notice Safely multiplies two numbers and divides by a third, avoiding overflow
     * @param a First multiplicand
     * @param b Second multiplicand
     * @param c Divisor
     * @return Result of (a * b) / c
     */
    function mulDiv(uint256 a, uint256 b, uint256 c) internal pure returns (uint256) {
        require(c != 0, "Math: Division by zero");
        
        // Check for overflow in multiplication
        if (a == 0 || b == 0) return 0;
        
        // Use assembly for more precise calculation
        uint256 result;
        assembly {
            // Store the result of a * b in result and resultHigh
            let resultHigh := mul(a, b)
            result := mul(a, b)
            
            // Check for overflow
            if iszero(eq(div(resultHigh, a), b)) {
                revert(0, 0)
            }
            
            // Divide by c
            result := div(result, c)
        }
        
        return result;
    }

    /**
     * @notice Calculates compound interest
     * @param principal The principal amount
     * @param rate The interest rate (in basis points, e.g., 500 = 5%)
     * @param time The time period
     * @param compounds Number of compounds per time period
     * @return The final amount after compound interest
     */
    function compoundInterest(
        uint256 principal,
        uint256 rate,
        uint256 time,
        uint256 compounds
    ) internal pure returns (uint256) {
        require(compounds > 0, "Math: Invalid compound frequency");
        
        uint256 ratePerCompound = rate / compounds;
        uint256 totalCompounds = compounds * time;
        
        uint256 result = principal;
        for (uint256 i = 0; i < totalCompounds; i++) {
            result = result * (10000 + ratePerCompound) / 10000;
        }
        
        return result;
    }
}
