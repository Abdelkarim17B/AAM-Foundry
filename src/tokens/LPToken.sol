// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IERC20Extended.sol";

/**
 * @title LPToken
 * @notice Liquidity Provider Token that represents shares in a liquidity pool
 * @dev This token is minted when users provide liquidity and burned when they remove it
 */
contract LPToken is ERC20, ERC20Burnable, Ownable, ILiquidityToken {
    address public immutable dexContract;
    bytes32 public immutable poolId;
    address public immutable tokenA;
    address public immutable tokenB;

    // Only the DEX contract can mint new LP tokens
    modifier onlyDEX() {
        require(msg.sender == dexContract, "LPToken: Only DEX can call");
        _;
    }

    /**
     * @notice Constructor for LP Token
     * @param _name Token name (e.g., "UniswapV2 LP Token")
     * @param _symbol Token symbol (e.g., "UNI-V2")
     * @param _dexContract Address of the DEX contract
     * @param _poolId Pool identifier
     * @param _tokenA First token in the pair
     * @param _tokenB Second token in the pair
     */
    constructor(
        string memory _name,
        string memory _symbol,
        address _dexContract,
        bytes32 _poolId,
        address _tokenA,
        address _tokenB
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
        require(_dexContract != address(0), "LPToken: Invalid DEX address");
        require(_tokenA != address(0) && _tokenB != address(0), "LPToken: Invalid token addresses");
        require(_tokenA != _tokenB, "LPToken: Identical tokens");

        dexContract = _dexContract;
        poolId = _poolId;
        tokenA = _tokenA;
        tokenB = _tokenB;

        // Transfer ownership to the DEX contract
        _transferOwnership(_dexContract);
    }

    /**
     * @notice Mint LP tokens to an account
     * @param account Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mint(address account, uint256 amount) external override onlyDEX {
        _mint(account, amount);
    }

    /**
     * @notice Burn LP tokens from caller's account
     * @param amount Amount of tokens to burn
     */
    function burn(uint256 amount) public override(ERC20Burnable, IERC20Burnable) {
        super.burn(amount);
    }

    /**
     * @notice Burn LP tokens from specified account
     * @param account Account to burn tokens from
     * @param amount Amount of tokens to burn
     */
    function burnFrom(address account, uint256 amount) public override(ERC20Burnable, IERC20Burnable) {
        super.burnFrom(account, amount);
    }

    /**
     * @notice Get the tokens that make up this liquidity pair
     * @return tokenA First token address
     * @return tokenB Second token address
     */
    function getTokens() external view override returns (address, address) {
        return (tokenA, tokenB);
    }

    /**
     * @notice Override decimals to return 18 (standard for LP tokens)
     * @return 18 decimals
     */
    function decimals() public pure override(ERC20, IERC20Extended) returns (uint8) {
        return 18;
    }

    /**
     * @notice Increase allowance for spender
     * @param spender Address to increase allowance for
     * @param addedValue Amount to increase by
     * @return Success boolean
     */
    function increaseAllowance(address spender, uint256 addedValue) 
        public 
        override 
        returns (bool) 
    {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /**
     * @notice Decrease allowance for spender
     * @param spender Address to decrease allowance for
     * @param subtractedValue Amount to decrease by
     * @return Success boolean
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) 
        public 
        override 
        returns (bool) 
    {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }
        return true;
    }

    /**
     * @notice Get token name
     * @return Token name
     */
    function name() public view override(ERC20, IERC20Extended) returns (string memory) {
        return super.name();
    }

    /**
     * @notice Get token symbol
     * @return Token symbol
     */
    function symbol() public view override(ERC20, IERC20Extended) returns (string memory) {
        return super.symbol();
    }

    /**
     * @notice Override transfer to add any necessary restrictions
     * @param to Recipient address
     * @param amount Amount to transfer
     * @return Success boolean
     */
    function transfer(address to, uint256 amount) public override(ERC20, IERC20) returns (bool) {
        return super.transfer(to, amount);
    }

    /**
     * @notice Override transferFrom to add any necessary restrictions
     * @param from Sender address
     * @param to Recipient address
     * @param amount Amount to transfer
     * @return Success boolean
     */
    function transferFrom(address from, address to, uint256 amount) 
        public 
        override(ERC20, IERC20) 
        returns (bool) 
    {
        return super.transferFrom(from, to, amount);
    }

    /**
     * @notice Override approve to add any necessary restrictions
     * @param spender Spender address
     * @param amount Amount to approve
     * @return Success boolean
     */
    function approve(address spender, uint256 amount) public override(ERC20, IERC20) returns (bool) {
        return super.approve(spender, amount);
    }

    /**
     * @notice Get balance of an account
     * @param account Account to check
     * @return Balance
     */
    function balanceOf(address account) public view override(ERC20, IERC20) returns (uint256) {
        return super.balanceOf(account);
    }

    /**
     * @notice Get total supply
     * @return Total supply
     */
    function totalSupply() public view override(ERC20, IERC20) returns (uint256) {
        return super.totalSupply();
    }

    /**
     * @notice Get allowance
     * @param owner Owner address
     * @param spender Spender address
     * @return Allowance amount
     */
    function allowance(address owner, address spender) 
        public 
        view 
        override(ERC20, IERC20) 
        returns (uint256) 
    {
        return super.allowance(owner, spender);
    }
}
