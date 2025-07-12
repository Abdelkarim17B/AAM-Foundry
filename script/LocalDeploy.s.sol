// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/core/SimpleDEX.sol";
import "../src/mocks/MockERC20.sol";

/**
 * @title LocalDeployScript
 * @notice Simple deployment script for local testing
 */
contract LocalDeployScript is Script {
    function run() external {
        // Use the default Anvil private key
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deployer:", deployer);
        console.log("Deployer balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy SimpleDEX
        SimpleDEX dex = new SimpleDEX(deployer); // Use deployer as fee recipient
        console.log("SimpleDEX deployed at:", address(dex));
        
        // Deploy test tokens
        MockERC20 tokenA = new MockERC20("Token A", "TKNA", 18);
        MockERC20 tokenB = new MockERC20("Token B", "TKNB", 18);
        MockERC20 weth = new MockERC20("Wrapped Ether", "WETH", 18);
        
        console.log("Token A deployed at:", address(tokenA));
        console.log("Token B deployed at:", address(tokenB));
        console.log("WETH deployed at:", address(weth));
        
        // Mint tokens to deployer
        uint256 mintAmount = 1000000 * 10**18; // 1M tokens
        tokenA.mint(deployer, mintAmount);
        tokenB.mint(deployer, mintAmount);
        weth.mint(deployer, mintAmount);
        
        console.log("Minted", mintAmount / 10**18, "tokens to deployer");
        
        // Create initial pools
        bytes32 poolAB = dex.createPool(address(tokenA), address(tokenB));
        bytes32 poolAETH = dex.createPool(address(tokenA), address(weth));
        bytes32 poolBETH = dex.createPool(address(tokenB), address(weth));
        
        console.log("Created pool A-B:", vm.toString(poolAB));
        console.log("Created pool A-ETH:", vm.toString(poolAETH));
        console.log("Created pool B-ETH:", vm.toString(poolBETH));
        
        // Add initial liquidity
        uint256 liquidityAmount = 10000 * 10**18; // 10K tokens
        
        tokenA.approve(address(dex), liquidityAmount * 3);
        tokenB.approve(address(dex), liquidityAmount * 3);
        weth.approve(address(dex), liquidityAmount * 3);
        
        dex.addLiquidity(poolAB, liquidityAmount, liquidityAmount, 0);
        dex.addLiquidity(poolAETH, liquidityAmount, liquidityAmount, 0);
        dex.addLiquidity(poolBETH, liquidityAmount, liquidityAmount, 0);
        
        console.log("Added initial liquidity to all pools");
        
        vm.stopBroadcast();
        
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("SimpleDEX:", address(dex));
        console.log("Token A:", address(tokenA));
        console.log("Token B:", address(tokenB));
        console.log("WETH:", address(weth));
        console.log("Pool A-B:", vm.toString(poolAB));
        console.log("Pool A-ETH:", vm.toString(poolAETH));
        console.log("Pool B-ETH:", vm.toString(poolBETH));
        console.log("Fee Recipient:", deployer);
        console.log("\n=== READY TO USE! ===");
        
        // Save addresses to a file for easy access
        string memory addresses = string.concat(
            "DEX_ADDRESS=", vm.toString(address(dex)), "\n",
            "TOKEN_A=", vm.toString(address(tokenA)), "\n",
            "TOKEN_B=", vm.toString(address(tokenB)), "\n",
            "WETH=", vm.toString(address(weth)), "\n",
            "POOL_AB=", vm.toString(poolAB), "\n",
            "POOL_A_ETH=", vm.toString(poolAETH), "\n",
            "POOL_B_ETH=", vm.toString(poolBETH)
        );
        
        vm.writeFile("deployed-addresses.txt", addresses);
        console.log("Addresses saved to deployed-addresses.txt");
    }
}
