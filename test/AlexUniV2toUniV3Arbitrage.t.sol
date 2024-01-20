// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/AlexUniV2toUniV3Arbitrage.sol";

contract AlexUniV2toUniV3ArbitrageTest is Test {
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address private constant UNISWAP_V2_ROUTER =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    // address private constant SUSHISWAP_V2_ROUTER =
    //     0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
    address[] private path = new address[](2);

    IWETH private weth = IWETH(WETH);
    IERC20 private usdc = IERC20(USDC);

    AlexUniV2toUniV3Arbitrage private uniV2FlashToUniV3;

    address private maker = makeAddr("Maker");

    address uniV3Pool = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;
    uint24 uniV3fee = 500;

    // WETH/USDC V3 0.05 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640

    function setUp() public {}

    function testUniswapV2FlashSwap() public {
        /////////
        //setUp//
        /////////
        vm.createSelectFork(vm.envString("FORK_URL") /*, 18995573*/);
        uniV2FlashToUniV3 = new AlexUniV2toUniV3Arbitrage();
        // Approve WETH fee
        uint wethMaxFee = 10e18;
        weth.deposit{value: wethMaxFee}();
        weth.approve(address(uniV2FlashToUniV3), wethMaxFee);

        // get some USDC
        path[0] = WETH;
        path[1] = USDC;
        IERC20(WETH).approve(UNISWAP_V2_ROUTER, 1e18);
        IUniswapV2Router02(UNISWAP_V2_ROUTER).swapExactTokensForTokens(
            1e18,
            0,
            path,
            address(this),
            block.timestamp
        )[1];
        usdc.approve(address(uniV2FlashToUniV3), 20000 * 1e6);
        console.log("USDC balance", IERC20(USDC).balanceOf(address(this)));

        //////////////
        //test start//
        //////////////

        // address pair = 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc;
        // WETH/USDC 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc
        // uint borrowAmountFromUniV2 = 20000 * 1e6;
        uint repayAmountToUniV2 = 2 * 1e18;

        console.log("------------------------------");
        console.log("-------------WETH-------------");
        console.log("------------------------------");
        uint balBefore = weth.balanceOf(address(this));
        console.log("caller WETH balance before", balBefore);
        uniV2FlashToUniV3.UniswapV2FlashSwap(
            USDC, // borrow from UniV2
            WETH, // repay to UniV2, profit or loss
            UNISWAP_V2_ROUTER,
            repayAmountToUniV2,
            uniV3Pool,
            uniV3fee
        );
        uint balAfter = weth.balanceOf(address(this));
        console.log("caller WETH balance after", balAfter);

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
        uint repayUSDCAmountToUniV2 = 1000 * 1e6;
        uniV2FlashToUniV3.UniswapV2FlashSwap(
            WETH, // borrow from UniV2
            USDC, // repay to UniV2, profit or loss
            UNISWAP_V2_ROUTER,
            repayUSDCAmountToUniV2,
            uniV3Pool,
            uniV3fee
        );
        uint usdcBalAfter = usdc.balanceOf(address(this));
        console.log("caller USDC balance after", usdcBalAfter);

        if (usdcBalAfter >= usdcBalBefore) {
            console.log("USDC profit", usdcBalAfter - usdcBalBefore);
        } else {
            console.log("USDC loss", usdcBalBefore - usdcBalAfter);
        }
    }

    function testUniV2toUniV3Requires() public {
        /////////
        //setUp//
        /////////
        vm.createSelectFork(vm.envString("FORK_URL") /*, 18995573*/);
        uniV2FlashToUniV3 = new AlexUniV2toUniV3Arbitrage();
        // Approve WETH fee
        uint wethMaxFee = 10e18;
        weth.deposit{value: wethMaxFee}();
        weth.approve(address(uniV2FlashToUniV3), wethMaxFee);

        // get some USDC
        path[0] = WETH;
        path[1] = USDC;
        IERC20(WETH).approve(UNISWAP_V2_ROUTER, 1e18);
        IUniswapV2Router02(UNISWAP_V2_ROUTER).swapExactTokensForTokens(
            1e18,
            0,
            path,
            address(this),
            block.timestamp
        )[1];
        usdc.approve(address(uniV2FlashToUniV3), 20000 * 1e6);
        console.log("USDC balance", IERC20(USDC).balanceOf(address(this)));

        //////////////
        //test start//
        //////////////
        vm.expectRevert("This pool does not exist");
        uint repayAmountToUniV2 = 2 * 1e18;
        uniV2FlashToUniV3.UniswapV2FlashSwap(
            address(0), // borrow from UniV2
            address(0), // repay to UniV2, profit or loss
            UNISWAP_V2_ROUTER,
            repayAmountToUniV2,
            uniV3Pool,
            uniV3fee
        );

        vm.expectRevert("Not from the right pool");
        bytes memory data = abi.encode(
            address(this),
            WETH,
            WETH,
            500
            // _tokenBorrow
        );
        uniV2FlashToUniV3.uniswapV2Call(address(this), 0, 0, data);
    }
}
