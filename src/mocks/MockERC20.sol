// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockERC20
 * @notice Mock ERC20 token for testing purposes
 * @dev Allows anyone to mint tokens for testing
 */
contract MockERC20 is ERC20, Ownable {
    uint8 private _decimals;
    
    /**
     * @notice Constructor for MockERC20
     * @param name_ Token name
     * @param symbol_ Token symbol
     * @param decimals_ Number of decimals
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) ERC20(name_, symbol_) Ownable(msg.sender) {
        _decimals = decimals_;
    }

    /**
     * @notice Return the number of decimals
     * @return Number of decimals
     */
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @notice Mint tokens to any address (for testing)
     * @param to Address to mint to
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /**
     * @notice Mint tokens to caller (for testing)
     * @param amount Amount to mint
     */
    function mint(uint256 amount) external {
        _mint(msg.sender, amount);
    }

    /**
     * @notice Burn tokens from caller
     * @param amount Amount to burn
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /**
     * @notice Burn tokens from any address (for testing)
     * @param from Address to burn from
     * @param amount Amount to burn
     */
    function burnFrom(address from, uint256 amount) external {
        _burn(from, amount);
    }

    /**
     * @notice Set allowance for testing purposes
     * @param owner Token owner
     * @param spender Spender address
     * @param amount Allowance amount
     */
    function setAllowance(address owner, address spender, uint256 amount) external {
        _approve(owner, spender, amount);
    }

    /**
     * @notice Force transfer for testing purposes
     * @param from From address
     * @param to To address
     * @param amount Amount to transfer
     */
    function forceTransfer(address from, address to, uint256 amount) external {
        _transfer(from, to, amount);
    }
}

/**
 * @title MockWETH
 * @notice Mock Wrapped ETH contract for testing
 * @dev Allows wrapping and unwrapping ETH
 */
contract MockWETH is MockERC20 {
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    constructor() MockERC20("Wrapped Ether", "WETH", 18) {}

    /**
     * @notice Wrap ETH to WETH
     */
    function deposit() external payable {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice Unwrap WETH to ETH
     * @param amount Amount to unwrap
     */
    function withdraw(uint256 amount) external {
        require(balanceOf(msg.sender) >= amount, "WETH: Insufficient balance");
        _burn(msg.sender, amount);
        payable(msg.sender).transfer(amount);
        emit Withdrawal(msg.sender, amount);
    }

    /**
     * @notice Fallback function to wrap ETH
     */
    receive() external payable {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }
}

/**
 * @title MockERC20WithFee
 * @notice Mock ERC20 token that charges fees on transfer
 * @dev Used for testing DEX behavior with fee-on-transfer tokens
 */
contract MockERC20WithFee is MockERC20 {
    uint256 public transferFeeRate = 100; // 1% fee (100 basis points)
    address public feeRecipient;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address feeRecipient_
    ) MockERC20(name_, symbol_, decimals_) {
        feeRecipient = feeRecipient_;
    }

    /**
     * @notice Set transfer fee rate
     * @param rate Fee rate in basis points
     */
    function setTransferFeeRate(uint256 rate) external onlyOwner {
        require(rate <= 1000, "Fee too high"); // Max 10%
        transferFeeRate = rate;
    }

    /**
     * @notice Set fee recipient
     * @param recipient New fee recipient
     */
    function setFeeRecipient(address recipient) external onlyOwner {
        feeRecipient = recipient;
    }

    /**
     * @notice Override transfer to charge fees
     * @param to Recipient
     * @param amount Amount to transfer
     * @return Success boolean
     */
    function transfer(address to, uint256 amount) public override returns (bool) {
        address owner = _msgSender();
        _transferWithFee(owner, to, amount);
        return true;
    }

    /**
     * @notice Override transferFrom to charge fees
     * @param from Sender
     * @param to Recipient
     * @param amount Amount to transfer
     * @return Success boolean
     */
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transferWithFee(from, to, amount);
        return true;
    }

    /**
     * @notice Internal function to handle fee-on-transfer
     * @param from Sender
     * @param to Recipient
     * @param amount Amount to transfer
     */
    function _transferWithFee(address from, address to, uint256 amount) internal {
        uint256 fee = (amount * transferFeeRate) / 10000;
        uint256 netAmount = amount - fee;

        if (fee > 0 && feeRecipient != address(0)) {
            _transfer(from, feeRecipient, fee);
        }
        _transfer(from, to, netAmount);
    }
}

/**
 * @title MockERC20Reverting
 * @notice Mock ERC20 that reverts on certain operations for testing
 * @dev Used to test error handling in the DEX
 */
contract MockERC20Reverting is MockERC20 {
    bool public shouldRevertOnTransfer = false;
    bool public shouldRevertOnApprove = false;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) MockERC20(name_, symbol_, decimals_) {}

    /**
     * @notice Toggle transfer reversion
     */
    function toggleTransferRevert() external {
        shouldRevertOnTransfer = !shouldRevertOnTransfer;
    }

    /**
     * @notice Toggle approve reversion
     */
    function toggleApproveRevert() external {
        shouldRevertOnApprove = !shouldRevertOnApprove;
    }

    /**
     * @notice Override transfer to potentially revert
     */
    function transfer(address to, uint256 amount) public override returns (bool) {
        if (shouldRevertOnTransfer) {
            revert("MockERC20: Transfer reverted");
        }
        return super.transfer(to, amount);
    }

    /**
     * @notice Override transferFrom to potentially revert
     */
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        if (shouldRevertOnTransfer) {
            revert("MockERC20: TransferFrom reverted");
        }
        return super.transferFrom(from, to, amount);
    }

    /**
     * @notice Override approve to potentially revert
     */
    function approve(address spender, uint256 amount) public override returns (bool) {
        if (shouldRevertOnApprove) {
            revert("MockERC20: Approve reverted");
        }
        return super.approve(spender, amount);
    }
}
