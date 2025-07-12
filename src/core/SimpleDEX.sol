// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../libraries/FixedPoint.sol";

/**
 * @title SimpleDEX
 * @dev Uniswap V2-style AMM with flash loans and TWAP oracles
 */
contract SimpleDEX is ReentrancyGuard, Pausable, Ownable {
    using SafeERC20 for IERC20;
    using Math for uint256;
    using FixedPoint for FixedPoint.uq112x112;

    struct Pool {
        address tokenA;
        address tokenB;
        uint256 reserveA;
        uint256 reserveB;
        uint256 totalSupply;
        mapping(address => uint256) liquidity;
        uint256 kLast; // fee calculation
        uint256 price0CumulativeLast; // TWAP
        uint256 price1CumulativeLast; // TWAP
        uint32 blockTimestampLast; // TWAP
    }

    // Constants
    uint256 public constant FEE_RATE = 3; // 0.3%
    uint256 public constant FEE_DENOMINATOR = 1000;
    uint256 public constant MINIMUM_LIQUIDITY = 10**3;
    uint256 public constant MAX_SLIPPAGE = 5000; // 50%

    // State
    mapping(bytes32 => Pool) public pools;
    mapping(bytes32 => bool) public poolExists;
    mapping(address => bool) public authorizedRouters;
    
    address public feeRecipient;
    uint256 public protocolFeeRate = 5; // 5% of trading fees
    bool public flashLoanEnabled = true;

    // Events
    event PoolCreated(
        address indexed tokenA, 
        address indexed tokenB, 
        bytes32 indexed poolId
    );
    event LiquidityAdded(
        address indexed provider,
        bytes32 indexed poolId,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    );
    event LiquidityRemoved(
        address indexed provider,
        bytes32 indexed poolId,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    );
    event Swap(
        address indexed trader,
        bytes32 indexed poolId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee
    );
    event FlashLoan(
        address indexed borrower,
        bytes32 indexed poolId,
        address token,
        uint256 amount,
        uint256 fee
    );

    // Modifiers
    modifier onlyAuthorizedRouter() {
        require(authorizedRouters[msg.sender] || msg.sender == owner(), "Unauthorized");
        _;
    }

    modifier validPool(bytes32 poolId) {
        require(poolExists[poolId], "Pool does not exist");
        _;
    }

    constructor(address _feeRecipient) Ownable(msg.sender) {
        feeRecipient = _feeRecipient;
    }

    // Create new trading pool
    function createPool(
        address tokenA, 
        address tokenB
    ) external returns (bytes32 poolId) {
        require(tokenA != tokenB, "DEX: Identical tokens");
        require(tokenA != address(0) && tokenB != address(0), "DEX: Zero address");
        
        // Keep tokens in consistent order
        if (tokenA > tokenB) {
            (tokenA, tokenB) = (tokenB, tokenA);
        }
        
        poolId = keccak256(abi.encodePacked(tokenA, tokenB));
        require(!poolExists[poolId], "DEX: Pool already exists");
        
        pools[poolId].tokenA = tokenA;
        pools[poolId].tokenB = tokenB;
        pools[poolId].blockTimestampLast = uint32(block.timestamp);
        poolExists[poolId] = true;
        
        emit PoolCreated(tokenA, tokenB, poolId);
    }

    /**
     * @notice Adds liquidity to an existing pool
     * @param poolId The pool identifier
     * @param amountA Amount of token A to add
     * @param amountB Amount of token B to add
     * @param minLiquidity Minimum liquidity tokens to receive
     * @return liquidity The amount of liquidity tokens minted
     */
    function addLiquidity(
        bytes32 poolId,
        uint256 amountA,
        uint256 amountB,
        uint256 minLiquidity
    ) external nonReentrant whenNotPaused validPool(poolId) returns (uint256 liquidity) {
        Pool storage pool = pools[poolId];
        
        // Update price oracle
        _updatePriceOracle(poolId);
        
        // Calculate optimal amounts
        if (pool.totalSupply > 0) {
            uint256 optimalAmountB = (amountA * pool.reserveB) / pool.reserveA;
            require(optimalAmountB <= amountB, "DEX: Insufficient tokenB amount");
            amountB = optimalAmountB;
        }
        
        // Transfer tokens
        IERC20(pool.tokenA).safeTransferFrom(msg.sender, address(this), amountA);
        IERC20(pool.tokenB).safeTransferFrom(msg.sender, address(this), amountB);
        
        // Calculate liquidity tokens
        if (pool.totalSupply == 0) {
            liquidity = Math.sqrt(amountA * amountB) - MINIMUM_LIQUIDITY;
            pool.liquidity[address(0)] = MINIMUM_LIQUIDITY; // Permanently lock minimum liquidity
        } else {
            liquidity = Math.min(
                (amountA * pool.totalSupply) / pool.reserveA,
                (amountB * pool.totalSupply) / pool.reserveB
            );
        }
        
        require(liquidity >= minLiquidity, "DEX: Insufficient liquidity minted");
        
        // Update pool state
        pool.reserveA += amountA;
        pool.reserveB += amountB;
        pool.totalSupply += liquidity;
        pool.liquidity[msg.sender] += liquidity;
        
        emit LiquidityAdded(msg.sender, poolId, amountA, amountB, liquidity);
    }

    /**
     * @notice Removes liquidity from a pool
     * @param poolId The pool identifier
     * @param liquidity Amount of liquidity tokens to burn
     * @param minAmountA Minimum amount of token A to receive
     * @param minAmountB Minimum amount of token B to receive
     * @return amountA Amount of token A received
     * @return amountB Amount of token B received
     */
    function removeLiquidity(
        bytes32 poolId,
        uint256 liquidity,
        uint256 minAmountA,
        uint256 minAmountB
    ) external nonReentrant whenNotPaused validPool(poolId) 
      returns (uint256 amountA, uint256 amountB) {
        Pool storage pool = pools[poolId];
        
        require(pool.liquidity[msg.sender] >= liquidity, "DEX: Insufficient liquidity");
        
        // Update price oracle
        _updatePriceOracle(poolId);
        
        // Calculate token amounts
        amountA = (liquidity * pool.reserveA) / pool.totalSupply;
        amountB = (liquidity * pool.reserveB) / pool.totalSupply;
        
        require(amountA >= minAmountA && amountB >= minAmountB, "DEX: Insufficient output");
        
        // Update pool state
        pool.liquidity[msg.sender] -= liquidity;
        pool.totalSupply -= liquidity;
        pool.reserveA -= amountA;
        pool.reserveB -= amountB;
        
        // Transfer tokens
        IERC20(pool.tokenA).safeTransfer(msg.sender, amountA);
        IERC20(pool.tokenB).safeTransfer(msg.sender, amountB);
        
        emit LiquidityRemoved(msg.sender, poolId, amountA, amountB, liquidity);
    }

    /**
     * @notice Swaps tokens in a pool
     * @param poolId The pool identifier
     * @param tokenIn Address of input token
     * @param amountIn Amount of input token
     * @param minAmountOut Minimum amount of output token
     * @param to Recipient address
     * @return amountOut Amount of output token received
     */
    function swap(
        bytes32 poolId,
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut,
        address to
    ) external nonReentrant whenNotPaused validPool(poolId) returns (uint256 amountOut) {
        Pool storage pool = pools[poolId];
        
        require(tokenIn == pool.tokenA || tokenIn == pool.tokenB, "DEX: Invalid token");
        require(amountIn > 0, "DEX: Zero amount");
        
        // Update price oracle
        _updatePriceOracle(poolId);
        
        bool isTokenA = tokenIn == pool.tokenA;
        (uint256 reserveIn, uint256 reserveOut) = isTokenA 
            ? (pool.reserveA, pool.reserveB) 
            : (pool.reserveB, pool.reserveA);
        
        // Calculate output amount
        amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        require(amountOut >= minAmountOut, "DEX: Slippage too high");
        
        // Calculate and collect fees
        uint256 fee = (amountIn * FEE_RATE) / FEE_DENOMINATOR;
        uint256 protocolFee = (fee * protocolFeeRate) / 100;
        
        // Transfer tokens
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        
        address tokenOut = isTokenA ? pool.tokenB : pool.tokenA;
        IERC20(tokenOut).safeTransfer(to, amountOut);
        
        // Send protocol fee
        if (protocolFee > 0) {
            IERC20(tokenIn).safeTransfer(feeRecipient, protocolFee);
        }
        
        // Update reserves
        if (isTokenA) {
            pool.reserveA += amountIn;
            pool.reserveB -= amountOut;
        } else {
            pool.reserveB += amountIn;
            pool.reserveA -= amountOut;
        }
        
        // Ensure K is maintained (accounting for fees)
        require(
            pool.reserveA * pool.reserveB >= pool.kLast,
            "DEX: K value decreased"
        );
        
        pool.kLast = pool.reserveA * pool.reserveB;
        
        emit Swap(msg.sender, poolId, tokenIn, tokenOut, amountIn, amountOut, fee);
    }

    /**
     * @notice Calculate output amount for a given input amount
     * @param amountIn Input amount
     * @param reserveIn Reserve of input token
     * @param reserveOut Reserve of output token
     * @return Amount of output token
     */
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256) {
        require(amountIn > 0 && reserveIn > 0 && reserveOut > 0, "DEX: Invalid amounts");
        
        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - FEE_RATE);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * FEE_DENOMINATOR) + amountInWithFee;
        
        return numerator / denominator;
    }

    /**
     * @notice Calculate input amount for a given output amount
     * @param amountOut Output amount
     * @param reserveIn Reserve of input token
     * @param reserveOut Reserve of output token
     * @return Amount of input token needed
     */
    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256) {
        require(amountOut > 0 && reserveIn > 0 && reserveOut > 0, "DEX: Invalid amounts");
        require(amountOut < reserveOut, "DEX: Insufficient liquidity");
        
        uint256 numerator = reserveIn * amountOut * FEE_DENOMINATOR;
        uint256 denominator = (reserveOut - amountOut) * (FEE_DENOMINATOR - FEE_RATE);
        
        return (numerator / denominator) + 1;
    }

    /**
     * @notice Calculate price impact for a trade
     * @param poolId The pool identifier
     * @param amountIn Input amount
     * @param tokenIn Input token address
     * @return Price impact in basis points
     */
    function getPriceImpact(
        bytes32 poolId,
        uint256 amountIn,
        address tokenIn
    ) external view validPool(poolId) returns (uint256) {
        Pool storage pool = pools[poolId];
        
        bool isTokenA = tokenIn == pool.tokenA;
        uint256 reserveOut = isTokenA ? pool.reserveB : pool.reserveA;
        
        uint256 amountOut = getAmountOut(
            amountIn,
            isTokenA ? pool.reserveA : pool.reserveB,
            reserveOut
        );
        
        return (amountOut * 10000) / reserveOut; // Returns basis points
    }

    /**
     * @notice Execute a flash loan
     * @param poolId The pool identifier
     * @param token Token to borrow
     * @param amount Amount to borrow
     * @param data Callback data
     */
    function flashLoan(
        bytes32 poolId,
        address token,
        uint256 amount,
        bytes calldata data
    ) external nonReentrant whenNotPaused validPool(poolId) {
        require(flashLoanEnabled, "DEX: Flash loans disabled");
        
        Pool storage pool = pools[poolId];
        require(token == pool.tokenA || token == pool.tokenB, "DEX: Invalid token");
        
        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        require(balanceBefore >= amount, "DEX: Insufficient liquidity");
        
        uint256 fee = (amount * FEE_RATE) / FEE_DENOMINATOR;
        
        // Transfer tokens to borrower
        IERC20(token).safeTransfer(msg.sender, amount);
        
        // Call borrower's callback
        IFlashLoanReceiver(msg.sender).executeOperation(token, amount, fee, data);
        
        // Ensure repayment
        uint256 balanceAfter = IERC20(token).balanceOf(address(this));
        require(balanceAfter >= balanceBefore + fee, "DEX: Flash loan not repaid");
        
        // Update reserves
        if (token == pool.tokenA) {
            pool.reserveA += fee;
        } else {
            pool.reserveB += fee;
        }
        
        emit FlashLoan(msg.sender, poolId, token, amount, fee);
    }

    /**
     * @notice Get pool information
     * @param poolId The pool identifier
     * @return tokenA Address of token A
     * @return tokenB Address of token B
     * @return reserveA Reserve of token A
     * @return reserveB Reserve of token B
     * @return totalSupply Total liquidity supply
     */
    function getPoolInfo(bytes32 poolId) external view validPool(poolId) returns (
        address tokenA,
        address tokenB,
        uint256 reserveA,
        uint256 reserveB,
        uint256 totalSupply
    ) {
        Pool storage pool = pools[poolId];
        return (
            pool.tokenA,
            pool.tokenB,
            pool.reserveA,
            pool.reserveB,
            pool.totalSupply
        );
    }

    /**
     * @notice Get user's liquidity balance in a pool
     * @param poolId The pool identifier
     * @param user User address
     * @return Liquidity balance
     */
    function getUserLiquidity(bytes32 poolId, address user) external view validPool(poolId) returns (uint256) {
        return pools[poolId].liquidity[user];
    }

    // Internal Functions
    function _updatePriceOracle(bytes32 poolId) internal {
        Pool storage pool = pools[poolId];
        
        uint32 blockTimestamp = uint32(block.timestamp);
        uint32 timeElapsed = blockTimestamp - pool.blockTimestampLast;
        
        if (timeElapsed > 0 && pool.reserveA > 0 && pool.reserveB > 0) {
            // Price0 = reserveB / reserveA
            // Price1 = reserveA / reserveB
            unchecked {
                pool.price0CumulativeLast += 
                    uint256(FixedPoint.fraction(uint112(pool.reserveB), uint112(pool.reserveA))._x) * timeElapsed;
                pool.price1CumulativeLast += 
                    uint256(FixedPoint.fraction(uint112(pool.reserveA), uint112(pool.reserveB))._x) * timeElapsed;
            }
        }
        
        pool.blockTimestampLast = blockTimestamp;
    }

    // Admin Functions
    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        feeRecipient = _feeRecipient;
    }

    function setProtocolFeeRate(uint256 _protocolFeeRate) external onlyOwner {
        require(_protocolFeeRate <= 20, "DEX: Fee too high"); // Max 20%
        protocolFeeRate = _protocolFeeRate;
    }

    function toggleFlashLoan() external onlyOwner {
        flashLoanEnabled = !flashLoanEnabled;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function authorizeRouter(address router) external onlyOwner {
        authorizedRouters[router] = true;
    }

    function revokeRouter(address router) external onlyOwner {
        authorizedRouters[router] = false;
    }
}

/**
 * @title IFlashLoanReceiver
 * @notice Interface for flash loan receivers
 */
interface IFlashLoanReceiver {
    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external;
}
