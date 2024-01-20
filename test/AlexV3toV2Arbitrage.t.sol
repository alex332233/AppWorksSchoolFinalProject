// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/AlexV3toV2Arbitrage.sol";

contract AlexUniswapV3toV2ArbitrageTest is Test {
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address private constant UNISWAP_V2_ROUTER =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address[] private path = new address[](2);

    IWETH private weth = IWETH(WETH);
    IERC20 private usdc = IERC20(USDC);

    AlexUniswapV3toV2Arbitrage private uniV3FlashToV2;

    function setUp() public {
        // vm.createSelectFork(vm.envString("FORK_URL") /*, 18995573*/);
        // uniV3FlashToV2 = new AlexUniswapV3toV2Arbitrage();
    }

    function testUniswapV3FlashSwap() public {
        vm.createSelectFork(vm.envString("FORK_URL") /*, 18995573*/);
        uniV3FlashToV2 = new AlexUniswapV3toV2Arbitrage();
        address pool = 0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8;
        uint amountIntoUniV3Pool = 2 * 1e18;

        // Approve WETH fee
        uint wethMaxFee = 10 * 1e18;
        weth.deposit{value: wethMaxFee}();
        weth.approve(address(uniV3FlashToV2), wethMaxFee);

        // get some USDC
        path[0] = WETH;
        path[1] = USDC;
        IERC20(WETH).approve(UNISWAP_V2_ROUTER, 10 * 1e18);
        IUniswapV2Router02(UNISWAP_V2_ROUTER).swapExactTokensForTokens(
            1e18,
            0,
            path,
            address(this),
            block.timestamp
        )[1];
        usdc.approve(address(uniV3FlashToV2), 20000 * 1e6);
        usdc.approve(address(UNISWAP_V2_ROUTER), 20000 * 1e6);
        console.log("USDC balance", IERC20(USDC).balanceOf(address(this)));

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

        console.log("------------------------------");
        console.log("-------------USDC-------------");
        console.log("------------------------------");
        uint usdcBalBefore = usdc.balanceOf(address(this));
        console.log("caller USDC balance before", usdcBalBefore);
        uint amountUSDCIntoUniV3Pool = 1000 * 1e6;
        uniV3FlashToV2.UniswapV3FlashSwap(
            pool,
            USDC,
            WETH,
            amountUSDCIntoUniV3Pool
        );
        uint usdcBalAfter = usdc.balanceOf(address(this));
        console.log("caller USDC balance after", usdcBalAfter);

        if (usdcBalAfter >= usdcBalBefore) {
            console.log("USDC profit", usdcBalAfter - usdcBalBefore);
        } else {
            console.log("USDC loss", usdcBalBefore - usdcBalAfter);
        }
    }

    function testV3toV2Requires() public {
        vm.createSelectFork(vm.envString("FORK_URL") /*, 18995573*/);
        uniV3FlashToV2 = new AlexUniswapV3toV2Arbitrage();

        vm.expectRevert("Unauthorized");
        uint amountIntoUniV3Pool = 3494222835789865; // 0.003494352835789865 WETH
        bytes memory data = abi.encode(
            msg.sender,
            WETH,
            WETH,
            WETH,
            amountIntoUniV3Pool,
            // fee,
            true
            // ... add more arguments here if needed
        );
        uniV3FlashToV2.uniswapV3SwapCallback(0, 0, data);
    }
}
