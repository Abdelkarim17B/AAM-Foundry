// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/core/SimpleDEX.sol";
import "../src/mocks/MockERC20.sol";

/**
 * @title DeployScript
 * @notice Deployment script for SimpleDEX and related contracts
 * @dev This script handles deployment to different networks (testnet/mainnet)
 */
contract DeployScript is Script {
    // Configuration
    address public constant MAINNET_FEE_RECIPIENT = 0x1234567890123456789012345678901234567890; // Replace with actual address
    address public constant TESTNET_FEE_RECIPIENT = 0x1111111111111111111111111111111111111111; // Replace with actual address
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deployer:", deployer);
        console.log("Deployer balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Determine which network we're on
        uint256 chainId = block.chainid;
        address feeRecipient = _getFeeRecipient(chainId);
        
        console.log("Chain ID:", chainId);
        console.log("Fee recipient:", feeRecipient);
        
        // Deploy SimpleDEX
        SimpleDEX dex = new SimpleDEX(feeRecipient);
        console.log("SimpleDEX deployed at:", address(dex));
        
        // Deploy test tokens for testnets
        if (_isTestnet(chainId)) {
            _deployTestTokens(dex, deployer);
        }
        
        vm.stopBroadcast();
        
        console.log("Deployment completed successfully!");
    }
    
    /**
     * @notice Deploy test tokens and create initial pools (testnet only)
     * @param dex The deployed DEX contract
     * @param deployer The deployer address
     */
    function _deployTestTokens(SimpleDEX dex, address deployer) internal {
        console.log("Deploying test tokens...");
        
        // Deploy test tokens
        MockERC20 tokenA = new MockERC20("Test Token A", "TTA", 18);
        MockERC20 tokenB = new MockERC20("Test Token B", "TTB", 18);
        MockERC20 tokenC = new MockERC20("Test Token C", "TTC", 6); // Different decimals
        MockWETH weth = new MockWETH();
        
        console.log("Token A deployed at:", address(tokenA));
        console.log("Token B deployed at:", address(tokenB));
        console.log("Token C deployed at:", address(tokenC));
        console.log("WETH deployed at:", address(weth));
        
        // Mint initial supply to deployer
        uint256 initialSupply = 1000000 * 10**18; // 1M tokens
        tokenA.mint(deployer, initialSupply);
        tokenB.mint(deployer, initialSupply);
        tokenC.mint(deployer, initialSupply * 10**6 / 10**18); // Adjust for 6 decimals
        weth.mint(deployer, initialSupply);
        
        console.log("Minted", initialSupply / 10**18, "tokens to deployer");
        
        // Create initial pools
        bytes32 poolIdAB = dex.createPool(address(tokenA), address(tokenB));
        bytes32 poolIdAC = dex.createPool(address(tokenA), address(tokenC));
        bytes32 poolIdAW = dex.createPool(address(tokenA), address(weth));
        
        console.log("Pool A-B created with ID:", vm.toString(poolIdAB));
        console.log("Pool A-C created with ID:", vm.toString(poolIdAC));
        console.log("Pool A-WETH created with ID:", vm.toString(poolIdAW));
        
        // Add initial liquidity to A-B pool
        uint256 liquidityAmountA = 10000 * 10**18; // 10K tokens
        uint256 liquidityAmountB = 10000 * 10**18; // 10K tokens
        
        tokenA.approve(address(dex), liquidityAmountA);
        tokenB.approve(address(dex), liquidityAmountB);
        
        uint256 liquidity = dex.addLiquidity(
            poolIdAB,
            liquidityAmountA,
            liquidityAmountB,
            0
        );
        
        console.log("Added initial liquidity:", liquidity);
        console.log("Initial liquidity provider:", deployer);
        
        // Add liquidity to A-WETH pool
        uint256 liquidityAmountWETH = 5 * 10**18; // 5 WETH
        uint256 liquidityAmountA2 = 15000 * 10**18; // 15K tokens (1 WETH = 3000 tokens)
        
        tokenA.approve(address(dex), liquidityAmountA2);
        weth.approve(address(dex), liquidityAmountWETH);
        
        uint256 liquidityAW = dex.addLiquidity(
            poolIdAW,
            liquidityAmountA2,
            liquidityAmountWETH,
            0
        );
        
        console.log("Added A-WETH liquidity:", liquidityAW);
    }
    
    /**
     * @notice Get the appropriate fee recipient for the chain
     * @param chainId The chain ID
     * @return The fee recipient address
     */
    function _getFeeRecipient(uint256 chainId) internal pure returns (address) {
        if (_isTestnet(chainId)) {
            return TESTNET_FEE_RECIPIENT;
        } else if (chainId == 1) { // Ethereum mainnet
            return MAINNET_FEE_RECIPIENT;
        } else {
            revert("Unsupported chain");
        }
    }
    
    /**
     * @notice Check if the chain is a testnet
     * @param chainId The chain ID
     * @return True if testnet, false otherwise
     */
    function _isTestnet(uint256 chainId) internal pure returns (bool) {
        return chainId == 5 || // Goerli
               chainId == 11155111 || // Sepolia
               chainId == 80001 || // Mumbai (Polygon testnet)
               chainId == 421613 || // Arbitrum Goerli
               chainId == 1337; // Local/Anvil
    }
}

/**
 * @title ConfigureScript
 * @notice Script to configure the DEX after deployment
 */
contract ConfigureScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address dexAddress = vm.envAddress("DEX_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        SimpleDEX dex = SimpleDEX(dexAddress);
        
        // Configure protocol fee rate (5%)
        dex.setProtocolFeeRate(5);
        console.log("Set protocol fee rate to 5%");
        
        // Enable flash loans (if not already enabled)
        if (!dex.flashLoanEnabled()) {
            dex.toggleFlashLoan();
            console.log("Enabled flash loans");
        }
        
        vm.stopBroadcast();
        
        console.log("Configuration completed!");
    }
}

/**
 * @title UpgradeScript
 * @notice Script for future contract upgrades (if implementing proxy pattern)
 */
contract UpgradeScript is Script {
    function run() external pure {
        // This would be used for proxy-based upgrades
        // For now, this is a placeholder
        console.log("Upgrade functionality not implemented - contract is not upgradeable");
    }
}

/**
 * @title VerifyScript
 * @notice Script to verify deployment and configuration
 */
contract VerifyScript is Script {
    function run() external view {
        address dexAddress = vm.envAddress("DEX_ADDRESS");
        SimpleDEX dex = SimpleDEX(dexAddress);
        
        console.log("=== DEX Verification ===");
        console.log("DEX Address:", dexAddress);
        console.log("Owner:", dex.owner());
        console.log("Fee Recipient:", dex.feeRecipient());
        console.log("Protocol Fee Rate:", dex.protocolFeeRate(), "%");
        console.log("Flash Loans Enabled:", dex.flashLoanEnabled());
        console.log("Contract Paused:", dex.paused());
        
        // Check constants
        console.log("Fee Rate:", dex.FEE_RATE(), "/ 1000");
        console.log("Minimum Liquidity:", dex.MINIMUM_LIQUIDITY());
        
        console.log("=== Verification Complete ===");
    }
}
