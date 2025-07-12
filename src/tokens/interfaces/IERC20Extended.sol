// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IERC20Extended
 * @notice Extended ERC20 interface with additional metadata functions
 * @dev Includes optional metadata that some tokens may not implement
 */
interface IERC20Extended is IERC20 {
    /**
     * @notice Returns the name of the token
     */
    function name() external view returns (string memory);

    /**
     * @notice Returns the symbol of the token
     */
    function symbol() external view returns (string memory);

    /**
     * @notice Returns the decimals of the token
     */
    function decimals() external view returns (uint8);

    /**
     * @notice Increases the allowance granted to spender by the caller
     * @param spender The address to increase allowance for
     * @param addedValue The amount to increase allowance by
     * @return True if the operation succeeded
     */
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);

    /**
     * @notice Decreases the allowance granted to spender by the caller
     * @param spender The address to decrease allowance for
     * @param subtractedValue The amount to decrease allowance by
     * @return True if the operation succeeded
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);
}

/**
 * @title IERC20Permit
 * @notice Interface for ERC20 tokens with permit functionality (EIP-2612)
 */
interface IERC20Permit {
    /**
     * @notice Sets approval using signature instead of requiring a transaction
     * @param owner Token owner's address
     * @param spender Address to approve
     * @param value Amount to approve
     * @param deadline Expiration timestamp for the signature
     * @param v Recovery byte of the signature
     * @param r First 32 bytes of the signature
     * @param s Second 32 bytes of the signature
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @notice Returns the current nonce for owner
     * @param owner Address to check nonce for
     * @return Current nonce value
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @notice Returns the domain separator
     * @return Domain separator hash
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

/**
 * @title IERC20Burnable
 * @notice Interface for burnable ERC20 tokens
 */
interface IERC20Burnable {
    /**
     * @notice Burns tokens from the caller's account
     * @param amount Amount of tokens to burn
     */
    function burn(uint256 amount) external;

    /**
     * @notice Burns tokens from specified account (requires allowance)
     * @param account Account to burn tokens from
     * @param amount Amount of tokens to burn
     */
    function burnFrom(address account, uint256 amount) external;
}

/**
 * @title IERC20Mintable
 * @notice Interface for mintable ERC20 tokens
 */
interface IERC20Mintable {
    /**
     * @notice Mints new tokens to specified account
     * @param account Account to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mint(address account, uint256 amount) external;
}

/**
 * @title ILiquidityToken
 * @notice Interface for liquidity provider tokens
 */
interface ILiquidityToken is IERC20Extended, IERC20Burnable, IERC20Mintable {
    /**
     * @notice Returns the DEX contract that manages this liquidity token
     */
    function dexContract() external view returns (address);

    /**
     * @notice Returns the pool ID this liquidity token represents
     */
    function poolId() external view returns (bytes32);

    /**
     * @notice Returns the two tokens that make up the liquidity pair
     */
    function getTokens() external view returns (address tokenA, address tokenB);
}
