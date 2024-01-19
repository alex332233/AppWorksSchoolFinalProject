// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/AlexUniV2toSushiV2Arbitrage.sol";

contract AlexUniV2toSushiV2ArbitrageTest is Test {
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address private constant UNISWAP_V2_ROUTER =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address private constant SUSHISWAP_V2_ROUTER =
        0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;

    IWETH private weth = IWETH(WETH);

    AlexUniV2toSushiV2Arbitrage private uniV2FlashToSushiV2;

    function setUp() public {
        vm.createSelectFork(vm.envString("FORK_URL") /*, 18995573*/);
        uniV2FlashToSushiV2 = new AlexUniV2toSushiV2Arbitrage();
    }

    function testUniswapV2FlashSwap() public {
        address pair = 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc;
        // WETH/USDC 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc
        // uint borrowAmountFromUniV2 = 20000 * 1e6;
        uint repayAmountToUniV2 = 2 * 1e18;

        // Approve WETH fee
        uint wethMaxFee = 1e18;
        weth.deposit{value: wethMaxFee}();
        weth.approve(address(uniV2FlashToSushiV2), wethMaxFee);

        uint balBefore = weth.balanceOf(address(this));
        console.log("caller WETH balance before", balBefore);
        uniV2FlashToSushiV2.UniswapV2FlashSwap(
            USDC, // borrow from UniV2
            WETH, // repay to UniV2, profit or loss
            UNISWAP_V2_ROUTER,
            SUSHISWAP_V2_ROUTER,
            // borrowAmountFromUniV2
            repayAmountToUniV2
        );
        uint balAfter = weth.balanceOf(address(this));
        console.log("caller WETH balance after", balAfter);

        if (balAfter >= balBefore) {
            console.log("WETH profit", balAfter - balBefore);
        } else {
            console.log("WETH loss", balBefore - balAfter);
        }
    }
}
