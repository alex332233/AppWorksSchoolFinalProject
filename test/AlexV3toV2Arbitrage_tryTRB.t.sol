// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/AlexV3toV2Arbitrage_tryTRB.sol";

contract AlexUniswapV3toV2ArbitrageTryTRBTest is Test {
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    // address private constant TURBO = 0xA35923162C49cF95e6BF26623385eb431ad920D3;
    address private constant TRB = 0x88dF592F8eb5D7Bd38bFeF7dEb0fBc02cf3778a0;

    IWETH private weth = IWETH(WETH);

    AlexUniswapV3toV2ArbitrageTryTRB private uniV3FlashToV2;

    function setUp() public {
        uint blockNumber = 18908920; // 24/1/1 00:05:23 UTC == 08:05:23 UTC+8
        vm.createSelectFork(vm.envString("FORK_URL"), blockNumber);
        console.log("Block number: ", block.number);
        uniV3FlashToV2 = new AlexUniswapV3toV2ArbitrageTryTRB();
    }

    function testUniswapV3FlashSwap() public {
        address pool = 0x8e40Fc101cC88B94744f1716A0a46e64929ef757;
        // TRB/WETH 0x8e40fc101cc88b94744f1716a0a46e64929ef757
        // WETH/TURBO 0x7baecE5d47f1BC5E1953FBE0E9931D54DAB6D810
        // WETH/USDC 0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8
        uint amountIntoUniV3Pool = 1.5 * 1e18; // 1 WETH
        uint poolWethBalance = weth.balanceOf(pool);
        console.log("WETH balance in pool", poolWethBalance);

        // Approve WETH fee
        uint wethMaxFee = 1e18;
        weth.deposit{value: wethMaxFee}();
        weth.approve(address(uniV3FlashToV2), wethMaxFee);

        // Approve TRB if loss
        IERC20(TRB).approve(address(uniV3FlashToV2), type(uint).max);

        uint balBefore = weth.balanceOf(address(this));
        uniV3FlashToV2.UniswapV3FlashSwap(pool, WETH, TRB, amountIntoUniV3Pool);
        uint balAfter = weth.balanceOf(address(this));

        if (balAfter >= balBefore) {
            console.log("WETH profit", balAfter - balBefore);
        } else {
            console.log("WETH loss", balBefore - balAfter);
        }
    }
}
