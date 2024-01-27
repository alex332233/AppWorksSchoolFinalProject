// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/AlexUniV2toSushiV2Arbitrage_copy.sol";
// uniswap utils
import {IUniswapV2Router01} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
// erc20 utils
import {TestWETH9} from "./helper/TestWETH9.sol";
import {TestERC20} from "./helper/TestERC20.sol";

contract AlexUniV2toSushiV2ArbitrageTestCopy is Test {
    // create pair variable and constant setting
    TestWETH9 public testWeth;
    TestERC20 public testUsdc;
    address public testWethAddr;
    address public testUsdcAddr;
    IUniswapV2Factory public uniswapV2Factory;
    IUniswapV2Factory public sushiSwapV2Factory;
    IUniswapV2Router01 public uniswapV2Router;
    IUniswapV2Router01 public sushiSwapV2Router;
    IUniswapV2Pair public wethUsdcPool;
    IUniswapV2Pair public wethUsdcSushiPool;

    address private constant UNISWAP_V2_ROUTER =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address private constant SUSHISWAP_V2_ROUTER =
        0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
    // add factory address for create pool
    address private constant UNISWAP_V2_FACTORY =
        0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address private constant SUSHISWAP_V2_FACTORY =
        0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac;

    address[] private path = new address[](2);

    AlexUniV2toSushiV2ArbitrageCopy private uniV2FlashToSushiV2;

    // address private maker = makeAddr("Maker");

    function setUp() public {
        /////////
        //setUp//
        /////////
        vm.createSelectFork(vm.envString("FORK_URL") /*, 18995573*/);
        console.log("deploy uniV2FlashToSushiV2");
        uniV2FlashToSushiV2 = new AlexUniV2toSushiV2ArbitrageCopy();
        console.log("uniV2FlashToSushiV2 deployed!");

        //////////////////
        //add pool setup//
        //////////////////
        console.log("pool setup start...");
        testWeth = new TestWETH9();
        testUsdc = new TestERC20("USD Coin", "USDC", 6);
        // Approve WETH fee
        uint wethMaxFee = 200 * 1e18;
        testWeth.deposit{value: wethMaxFee}();
        testWeth.approve(address(uniV2FlashToSushiV2), wethMaxFee);

        testWethAddr = address(testWeth);
        testUsdcAddr = address(testUsdc);
        address wethUsdcUnipoolAddr = IUniswapV2Factory(UNISWAP_V2_FACTORY)
            .createPair(testWethAddr, testUsdcAddr);
        address wethUsdcSushipoolAddr = IUniswapV2Factory(SUSHISWAP_V2_FACTORY)
            .createPair(testWethAddr, testUsdcAddr);
        vm.label(UNISWAP_V2_FACTORY, "UniswapV2Factory");
        vm.label(SUSHISWAP_V2_FACTORY, "SushiSwapV2Factory");
        vm.label(UNISWAP_V2_ROUTER, "UniswapV2Router");
        vm.label(SUSHISWAP_V2_ROUTER, "SushiSwapV2Router");
        vm.label(wethUsdcUnipoolAddr, "WethUsdcUniPool");
        vm.label(wethUsdcSushipoolAddr, "WethUsdcSushiPool");
        vm.label(address(testWethAddr), "testWETH9");
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
        uint256 repayETH = 5 ether;
        uint balBefore = testWeth.balanceOf(address(this));
        console.log("caller WETH balance before", balBefore);
        uniV2FlashToSushiV2.UniswapV2FlashSwap(
            address(testWethAddr),
            address(testUsdcAddr),
            address(UNISWAP_V2_ROUTER),
            address(SUSHISWAP_V2_ROUTER),
            repayETH
        );
        uint balAfter = testWeth.balanceOf(address(this));
        console.log("caller WETH balance after", balAfter);

        if (balAfter >= balBefore) {
            console.log("WETH profit", balAfter - balBefore);
        } else {
            console.log("WETH loss", balBefore - balAfter);
        }
        // assertEq(usdc.balanceOf(address(arbitrage)), 98184746);
    }
}
