// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title SafeTransfer
 * @notice Safe token transfer utilities that handle tokens with different return value behaviors
 * @dev Some tokens don't return a boolean on transfer/transferFrom, this library handles that
 */
library SafeTransfer {
    /**
     * @notice Safely transfer tokens from one address to another
     * @param token The token contract
     * @param from Source address
     * @param to Destination address
     * @param amount Amount to transfer
     */
    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 amount
    ) internal {
        bytes memory data = abi.encodeWithSelector(
            token.transferFrom.selector,
            from,
            to,
            amount
        );
        
        _callOptionalReturn(token, data);
    }

    /**
     * @notice Safely transfer tokens to an address
     * @param token The token contract
     * @param to Destination address
     * @param amount Amount to transfer
     */
    function safeTransfer(
        IERC20 token,
        address to,
        uint256 amount
    ) internal {
        bytes memory data = abi.encodeWithSelector(
            token.transfer.selector,
            to,
            amount
        );
        
        _callOptionalReturn(token, data);
    }

    /**
     * @notice Safely approve token spending
     * @param token The token contract
     * @param spender Address to approve
     * @param amount Amount to approve
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 amount
    ) internal {
        // To change the approve amount you first have to reduce the addresses`
        // allowance to zero by calling `approve(_spender, 0)` if it is not
        // already 0 to mitigate the race condition described here:
        // https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
        require(
            (amount == 0) || (token.allowance(address(this), spender) == 0),
            "SafeTransfer: approve from non-zero to non-zero allowance"
        );
        
        bytes memory data = abi.encodeWithSelector(
            token.approve.selector,
            spender,
            amount
        );
        
        _callOptionalReturn(token, data);
    }

    /**
     * @notice Safely increase allowance
     * @param token The token contract
     * @param spender Address to approve
     * @param amount Amount to increase allowance by
     */
    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 amount
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + amount;
        bytes memory data = abi.encodeWithSelector(
            token.approve.selector,
            spender,
            newAllowance
        );
        
        _callOptionalReturn(token, data);
    }

    /**
     * @notice Safely decrease allowance
     * @param token The token contract
     * @param spender Address to approve
     * @param amount Amount to decrease allowance by
     */
    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 amount
    ) internal {
        uint256 currentAllowance = token.allowance(address(this), spender);
        require(currentAllowance >= amount, "SafeTransfer: decreased allowance below zero");
        
        bytes memory data = abi.encodeWithSelector(
            token.approve.selector,
            spender,
            currentAllowance - amount
        );
        
        _callOptionalReturn(token, data);
    }

    /**
     * @notice Get the balance of an address, handling tokens that revert on zero balance
     * @param token The token contract
     * @param account Address to check balance for
     * @return balance The balance of the account
     */
    function safeBalanceOf(IERC20 token, address account) internal view returns (uint256 balance) {
        bytes memory data = abi.encodeWithSelector(token.balanceOf.selector, account);
        
        (bool success, bytes memory returnData) = address(token).staticcall(data);
        
        if (success && returnData.length >= 32) {
            balance = abi.decode(returnData, (uint256));
        } else {
            // If the call failed or returned unexpected data, assume balance is 0
            balance = 0;
        }
    }

    /**
     * @notice Internal function to handle optional return values
     * @param token The token contract
     * @param data The call data
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism,
        // since we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        (bool success, bytes memory returndata) = address(token).call(data);
        
        require(success, "SafeTransfer: low-level call failed");

        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeTransfer: ERC20 operation did not succeed");
        }
    }

    /**
     * @notice Check if an address is a contract
     * @param account Address to check
     * @return True if the address is a contract
     */
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /**
     * @notice Safely get token decimals
     * @param token The token contract
     * @return decimals Number of decimals (defaults to 18 if call fails)
     */
    function safeDecimals(IERC20 token) internal view returns (uint8 decimals) {
        bytes memory data = abi.encodeWithSignature("decimals()");
        
        (bool success, bytes memory returnData) = address(token).staticcall(data);
        
        if (success && returnData.length >= 32) {
            decimals = abi.decode(returnData, (uint8));
        } else {
            // Default to 18 decimals if the call fails
            decimals = 18;
        }
    }

    /**
     * @notice Safely get token symbol
     * @param token The token contract
     * @return symbol Token symbol (defaults to empty string if call fails)
     */
    function safeSymbol(IERC20 token) internal view returns (string memory symbol) {
        bytes memory data = abi.encodeWithSignature("symbol()");
        
        (bool success, bytes memory returnData) = address(token).staticcall(data);
        
        if (success && returnData.length > 0) {
            symbol = abi.decode(returnData, (string));
        } else {
            symbol = "";
        }
    }

    /**
     * @notice Safely get token name
     * @param token The token contract
     * @return name Token name (defaults to empty string if call fails)
     */
    function safeName(IERC20 token) internal view returns (string memory name) {
        bytes memory data = abi.encodeWithSignature("name()");
        
        (bool success, bytes memory returnData) = address(token).staticcall(data);
        
        if (success && returnData.length > 0) {
            name = abi.decode(returnData, (string));
        } else {
            name = "";
        }
    }
}
