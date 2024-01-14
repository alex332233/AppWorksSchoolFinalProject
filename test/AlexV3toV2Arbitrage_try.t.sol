// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/AlexV3toV2Arbitrage_try.sol";

contract AlexUniswapV3toV2ArbitrageTryTest is Test {
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address private constant TURBO = 0xA35923162C49cF95e6BF26623385eb431ad920D3;

    IWETH private weth = IWETH(WETH);

    AlexUniswapV3toV2ArbitrageTry private uniV3FlashToV2;

    function setUp() public {
        uint blockNumber = 18891170;
        vm.createSelectFork(vm.envString("FORK_URL"), blockNumber);
        console.log("Block number: ", block.number);
        uniV3FlashToV2 = new AlexUniswapV3toV2ArbitrageTry();
    }

    function testUniswapV3FlashSwap() public {
        address pool = 0x7baecE5d47f1BC5E1953FBE0E9931D54DAB6D810;
        // WETH/TURBO 0x7baecE5d47f1BC5E1953FBE0E9931D54DAB6D810
        // WETH/USDC 0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8
        uint amountIntoUniV3Pool = 3494222835789865; // 0.003494352835789865 WETH
        // 19817463299396421665729  // 19,817.463299396421665729 Turbo
        uint poolWethBalance = weth.balanceOf(pool);
        console.log("WETH balance in pool", poolWethBalance);

        // Approve WETH fee
        uint wethMaxFee = 1e18;
        weth.deposit{value: wethMaxFee}();
        weth.approve(address(uniV3FlashToV2), wethMaxFee);

        uint balBefore = weth.balanceOf(address(this));
        uniV3FlashToV2.UniswapV3FlashSwap(
            pool,
            WETH,
            TURBO,
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
