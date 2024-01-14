// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/AlexV3toV2Arbitrage.sol";

contract AlexUniswapV3toV2ArbitrageTest is Test {
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    IWETH private weth = IWETH(WETH);

    AlexUniswapV3toV2Arbitrage private uniV3FlashToV2;

    function setUp() public {
        vm.createSelectFork(vm.envString("FORK_URL") /*, 18995573*/);
        uniV3FlashToV2 = new AlexUniswapV3toV2Arbitrage();
    }

    function testUniswapV3FlashSwap() public {
        address pool = 0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8;
        uint amountIntoUniV3Pool = 2 * 1e18;

        // Approve WETH fee
        uint wethMaxFee = 1e18;
        weth.deposit{value: wethMaxFee}();
        weth.approve(address(uniV3FlashToV2), wethMaxFee);

        uint balBefore = weth.balanceOf(address(this));
        uniV3FlashToV2.UniswapV3FlashSwap(
            pool,
            WETH,
            USDC,
            amountIntoUniV3Pool
        );
        uint balAfter = weth.balanceOf(address(this));

        if (balAfter >= balBefore) {
            console.log("WETH profit", balAfter - balBefore);
        } else {
            console.log("WETH loss", balBefore - balAfter);
        }
    }
}
