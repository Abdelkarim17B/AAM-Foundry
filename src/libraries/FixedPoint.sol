// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title FixedPoint
 * @notice A library for handling binary fixed point numbers
 * @dev This library implements UQ112x112 format (112 bits for integer part, 112 bits for fractional part)
 * Used for price calculations and TWAP (Time-Weighted Average Price) implementations
 */
library FixedPoint {
    uint224 constant Q112 = 2**112;

    // A UQ112x112 is encoded as a uint224 with the upper 112 bits containing the integer part
    // and the lower 112 bits containing the fractional part
    struct uq112x112 {
        uint224 _x;
    }

    // A UQ144x112 is encoded as a uint256 with the upper 144 bits containing the integer part
    // and the lower 112 bits containing the fractional part
    struct uq144x112 {
        uint256 _x;
    }

    /**
     * @notice Encode a uint112 as a UQ112x112
     * @param x The uint112 to encode
     * @return A UQ112x112 representation of x
     */
    function encode(uint112 x) internal pure returns (uq112x112 memory) {
        return uq112x112(uint224(x) << 112);
    }

    /**
     * @notice Encode a uint144 as a UQ144x112
     * @param x The uint144 to encode
     * @return A UQ144x112 representation of x
     */
    function encode144(uint144 x) internal pure returns (uq144x112 memory) {
        return uq144x112(uint256(x) << 112);
    }

    /**
     * @notice Divide a UQ112x112 by a uint112, returning a UQ112x112
     * @param self The UQ112x112 dividend
     * @param x The uint112 divisor
     * @return A UQ112x112 representation of self / x
     */
    function div(uq112x112 memory self, uint112 x) internal pure returns (uq112x112 memory) {
        require(x != 0, "FixedPoint: DIV_BY_ZERO");
        return uq112x112(self._x / uint224(x));
    }

    /**
     * @notice Multiply a UQ112x112 by a uint, returning a UQ144x112
     * @param self The UQ112x112 multiplicand
     * @param x The uint multiplier
     * @return A UQ144x112 representation of self * x
     */
    function mul(uq112x112 memory self, uint256 x) internal pure returns (uq144x112 memory) {
        require(x <= type(uint144).max, "FixedPoint: MULTIPLICATION_OVERFLOW");
        return uq144x112(self._x * x);
    }

    /**
     * @notice Create a fraction UQ112x112 from two uint112s
     * @param numerator The numerator
     * @param denominator The denominator
     * @return A UQ112x112 representation of numerator / denominator
     */
    function fraction(uint112 numerator, uint112 denominator) internal pure returns (uq112x112 memory) {
        require(denominator > 0, "FixedPoint: DIV_BY_ZERO");
        return uq112x112((uint224(numerator) << 112) / denominator);
    }

    /**
     * @notice Decode a UQ112x112 into a uint with a specific granularity
     * @param self The UQ112x112 to decode
     * @param granularity The granularity to use for decoding
     * @return The decoded uint
     */
    function decode(uq112x112 memory self, uint8 granularity) internal pure returns (uint) {
        return uint(self._x >> (112 - granularity));
    }

    /**
     * @notice Decode a UQ144x112 into a uint with a specific granularity
     * @param self The UQ144x112 to decode
     * @param granularity The granularity to use for decoding
     * @return The decoded uint
     */
    function decode144(uq144x112 memory self, uint8 granularity) internal pure returns (uint) {
        return uint(self._x >> (112 - granularity));
    }

    /**
     * @notice Convert a UQ112x112 to a regular uint112 (truncating fractional part)
     * @param self The UQ112x112 to convert
     * @return The integer part as uint112
     */
    function toUint112(uq112x112 memory self) internal pure returns (uint112) {
        return uint112(self._x >> 112);
    }

    /**
     * @notice Convert a UQ144x112 to a regular uint144 (truncating fractional part)
     * @param self The UQ144x112 to convert
     * @return The integer part as uint144
     */
    function toUint144(uq144x112 memory self) internal pure returns (uint144) {
        return uint144(self._x >> 112);
    }

    /**
     * @notice Square root calculation for UQ112x112
     * @param self The UQ112x112 to calculate square root for
     * @return A UQ112x112 representation of sqrt(self)
     */
    function sqrt(uq112x112 memory self) internal pure returns (uq112x112 memory) {
        if (self._x <= 1) {
            return uq112x112(self._x);
        }

        uint224 x = self._x;
        uint224 result = 1;
        
        // Use Newton's method for square root approximation
        if (x >= 0x100000000000000000000000000000000) {
            result <<= 64;
            x >>= 128;
        }
        if (x >= 0x10000000000000000) {
            result <<= 32;
            x >>= 64;
        }
        if (x >= 0x100000000) {
            result <<= 16;
            x >>= 32;
        }
        if (x >= 0x10000) {
            result <<= 8;
            x >>= 16;
        }
        if (x >= 0x100) {
            result <<= 4;
            x >>= 8;
        }
        if (x >= 0x10) {
            result <<= 2;
            x >>= 4;
        }
        if (x >= 0x4) {
            result <<= 1;
        }

        // Refine using Newton's method
        result = (result + self._x / result) >> 1;
        result = (result + self._x / result) >> 1;
        result = (result + self._x / result) >> 1;
        result = (result + self._x / result) >> 1;
        result = (result + self._x / result) >> 1;
        result = (result + self._x / result) >> 1;
        result = (result + self._x / result) >> 1;

        uint224 roundedDownResult = self._x / result;
        if (result > roundedDownResult) {
            result = roundedDownResult;
        }

        return uq112x112(result);
    }

    /**
     * @notice Reciprocal (1/x) calculation for UQ112x112
     * @param self The UQ112x112 to calculate reciprocal for
     * @return A UQ112x112 representation of 1/self
     */
    function reciprocal(uq112x112 memory self) internal pure returns (uq112x112 memory) {
        require(self._x != 0, "FixedPoint: DIVISION_BY_ZERO");
        return uq112x112(uint224(Q112) * Q112 / self._x);
    }
}
