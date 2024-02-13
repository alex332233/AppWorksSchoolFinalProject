// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/AlexUniV2toSushiV2Arbitrage_PNL.sol";
// uniswap utils
import {IUniswapV2Router01} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
// erc20 utils
// import {TestWETH9} from "./helper/TestWETH9.sol";
import {TestERC20} from "./helper/TestERC20.sol";

contract AlexUniV2toSushiV2ArbitrageTestPNL is Test {
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address private constant UNISWAP_V2_ROUTER =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address private constant SUSHISWAP_V2_ROUTER =
        0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
    address[] private path = new address[](2);

    IWETH private weth = IWETH(WETH);
    IERC20 private usdc = IERC20(USDC);

    AlexUniV2toSushiV2ArbitragePNL private uniV2FlashToSushiV2;

    ///////////////////////
    //for test pool setup//
    ///////////////////////

    // create pair variable and constant setting
    TestERC20 public testUsdc;
    address public testUsdcAddr;
    IUniswapV2Factory public uniswapV2Factory;
    IUniswapV2Factory public sushiSwapV2Factory;
    IUniswapV2Router01 public uniswapV2Router;
    IUniswapV2Router01 public sushiSwapV2Router;
    IUniswapV2Pair public wethUsdcPool;
    IUniswapV2Pair public wethUsdcSushiPool;
    // add factory address for create pool
    address private constant UNISWAP_V2_FACTORY =
        0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address private constant SUSHISWAP_V2_FACTORY =
        0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac;

    function setUp() public {
        vm.createSelectFork(vm.envString("FORK_URL") /*, 18995573*/);
        console.log("deploy uniV2FlashToSushiV2");
        uniV2FlashToSushiV2 = new AlexUniV2toSushiV2ArbitragePNL();
        console.log("uniV2FlashToSushiV2 deployed!");

        //////////////////
        //add pool setup//
        //////////////////
        console.log("pool setup start...");
        // testWeth = new TestWETH9();
        testUsdc = new TestERC20("USD Coin", "USDC", 6);
        // Approve WETH fee
        uint wethMaxFee = 200 * 1e18;
        weth.deposit{value: wethMaxFee}();
        weth.approve(address(uniV2FlashToSushiV2), wethMaxFee);

        // testWethAddr = address(testWeth);
        testUsdcAddr = address(testUsdc);
        address wethUsdcUnipoolAddr = IUniswapV2Factory(UNISWAP_V2_FACTORY)
            .createPair(WETH, testUsdcAddr);
        address wethUsdcSushipoolAddr = IUniswapV2Factory(SUSHISWAP_V2_FACTORY)
            .createPair(WETH, testUsdcAddr);
        vm.label(UNISWAP_V2_FACTORY, "UniswapV2Factory");
        vm.label(SUSHISWAP_V2_FACTORY, "SushiSwapV2Factory");
        vm.label(UNISWAP_V2_ROUTER, "UniswapV2Router");
        vm.label(SUSHISWAP_V2_ROUTER, "SushiSwapV2Router");
        vm.label(wethUsdcUnipoolAddr, "WethUsdcUniPool");
        vm.label(wethUsdcSushipoolAddr, "WethUsdcSushiPool");
        vm.label(WETH, "WETH");
        vm.label(address(testUsdcAddr), "testUSDC");

        console.log("pool setup complete!");
        console.log("wethUsdcUnipoolAddr", wethUsdcUnipoolAddr);
        console.log("wethUsdcSushipoolAddr", wethUsdcSushipoolAddr);

        // get some testUSDC
        testUsdc.mint(address(this), 20000 * 1e6);
        testUsdc.approve(UNISWAP_V2_ROUTER, 10000 * 1e6);
        testUsdc.approve(SUSHISWAP_V2_ROUTER, 10000 * 1e6);
        console.log("testUSDC balance", testUsdc.balanceOf(address(this)));

        // pool setting
        IUniswapV2Router01(UNISWAP_V2_ROUTER).addLiquidityETH{value: 50 ether}(
            testUsdcAddr,
            4_000 * 10 ** testUsdc.decimals(),
            0,
            0,
            address(this),
            block.timestamp
        );
        (uint256 token0Reserve, uint256 token1Reserve, ) = IUniswapV2Pair(
            wethUsdcUnipoolAddr
        ).getReserves();
        console.log("wethUsdcUnipool usdc reserve", token0Reserve);
        console.log("wethUsdcUnipool weth reserve", token1Reserve);
        console.log(
            "LP balance of this address",
            IUniswapV2Pair(wethUsdcUnipoolAddr).balanceOf(address(this))
        );
        IUniswapV2Router01(SUSHISWAP_V2_ROUTER).addLiquidityETH{
            value: 50 ether
        }(
            testUsdcAddr,
            6_000 * 10 ** testUsdc.decimals(),
            0,
            0,
            address(this),
            block.timestamp
        );
    }

    function testProfit() public {
        //////////////
        //test start//
        //////////////
        uint256 repayUSDC = 800 * 1e6;
        uint balBefore = testUsdc.balanceOf(address(this));
        console.log("caller USDC balance before", balBefore);
        uniV2FlashToSushiV2.UniswapV2FlashSwap(
            WETH,
            address(testUsdcAddr),
            address(UNISWAP_V2_ROUTER),
            address(SUSHISWAP_V2_ROUTER),
            repayUSDC
        );
        uint balAfter = testUsdc.balanceOf(address(this));
        console.log("caller USDC balance after", balAfter);

        if (balAfter >= balBefore) {
            console.log("USDC profit", balAfter - balBefore);
        } else {
            console.log("USDC loss", balBefore - balAfter);
        }
        // assertEq(usdc.balanceOf(address(arbitrage)), 98184746);
    }

    function testUniswapV2FlashSwap() public {
        /////////
        //setUp//
        /////////
        // vm.createSelectFork(vm.envString("FORK_URL") /*, 18995573*/);
        // uniV2FlashToSushiV2 = new AlexUniV2toSushiV2ArbitragePNL();
        // // Approve WETH fee
        // uint wethMaxFee = 10e18;
        // weth.deposit{value: wethMaxFee}();
        // weth.approve(address(uniV2FlashToSushiV2), wethMaxFee);

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
        usdc.approve(address(uniV2FlashToSushiV2), 20000 * 1e6);
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

        console.log("------------------------------");
        console.log("-------------USDC-------------");
        console.log("------------------------------");
        uint usdcBalBefore = usdc.balanceOf(address(this));
        console.log("caller USDC balance before", usdcBalBefore);
        uint repayUSDCAmountToUniV2 = 1000 * 1e6;
        uniV2FlashToSushiV2.UniswapV2FlashSwap(
            WETH, // borrow from UniV2
            USDC, // repay to UniV2, profit or loss
            UNISWAP_V2_ROUTER,
            SUSHISWAP_V2_ROUTER,
            // borrowAmountFromUniV2
            repayUSDCAmountToUniV2
        );
        uint usdcBalAfter = usdc.balanceOf(address(this));
        console.log("caller USDC balance after", usdcBalAfter);

        if (usdcBalAfter >= usdcBalBefore) {
            console.log("USDC profit", usdcBalAfter - usdcBalBefore);
        } else {
            console.log("USDC loss", usdcBalBefore - usdcBalAfter);
        }
    }

    function testRequires() public {
        /////////
        //setUp//
        /////////
        // vm.createSelectFork(vm.envString("FORK_URL") /*, 18995573*/);
        // uniV2FlashToSushiV2 = new AlexUniV2toSushiV2ArbitragePNL();
        // // Approve WETH fee
        // uint wethMaxFee = 10e18;
        // weth.deposit{value: wethMaxFee}();
        // weth.approve(address(uniV2FlashToSushiV2), wethMaxFee);

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
        usdc.approve(address(uniV2FlashToSushiV2), 20000 * 1e6);
        console.log("USDC balance", IERC20(USDC).balanceOf(address(this)));

        //////////////
        //test start//
        //////////////
        vm.expectRevert("This pool does not exist");
        uint repayAmountToUniV2 = 2 * 1e18;
        uniV2FlashToSushiV2.UniswapV2FlashSwap(
            address(0),
            address(0),
            UNISWAP_V2_ROUTER,
            SUSHISWAP_V2_ROUTER,
            repayAmountToUniV2
        );

        vm.expectRevert("Not from the right pool");
        bytes memory data = abi.encode(
            address(this),
            0,
            0,
            WETH
            // _tokenBorrow
        );
        uniV2FlashToSushiV2.uniswapV2Call(address(this), 0, 0, data);
    }
}
