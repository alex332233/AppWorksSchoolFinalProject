// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/AlexV3toV2Arbitrage_profit.sol";
import {IUniswapV2Router01} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {TestERC20} from "./helper/TestERC20.sol";

contract AlexUniswapV3toV2ArbitrageProfitTest is Test {
    // create UniV2pair testUSDC 4000 WETH 50 settings
    TestERC20 public testUsdc;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    IWETH public iweth = IWETH(WETH);
    address public testUsdcAddr;
    IUniswapV2Factory public uniswapV2Factory;
    IUniswapV2Router01 public uniswapV2Router;
    IUniswapV2Pair public wethUsdcPool;

    uint public tokenId;
    uint public liquidity;
    uint public amount0;
    uint public amount1;

    address private constant UNISWAP_V2_ROUTER =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address private constant UNISWAP_V2_FACTORY =
        0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;

    // create UniV3pool testUSDC 6000 WETH 50
    // INonfungiblePositionManager
    INonfungiblePositionManager public nonfungiblePositionManager =
        INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    address uniV3Pool;
    uint24 uniV3fee = 500;
    uint160 sqrtPriceX96 = 1771580069046490802230235074;
    // 9507379500000000000000000000000; 120 * 2 ** 96
    uint256 amount0ToMint = 4000 * 1e6;
    uint256 amount1ToMint = 50 * 1e18;
    int24 constant MIN_TICK = -100000;
    int24 constant MAX_TICK = 100000;

    // arbitrage contract
    AlexUniswapV3toV2ArbitrageProfit private uniV3FlashToV2;

    function setUp() public {
        /////////
        //setUp//
        /////////
        vm.createSelectFork(vm.envString("FORK_URL") /*, 18995573*/);
        console.log("deploy uniV3FlashToUniV2");
        uniV3FlashToV2 = new AlexUniswapV3toV2ArbitrageProfit();
        console.log("uniV3FlashToUniV2 deployed!");

        //////////////////
        //add pool setup//
        //////////////////
        console.log("pool setup start...");
        // testWeth = new TestWETH9();
        testUsdc = new TestERC20("AlextestUSD Coin", "AlextestUSDC", 6);

        // create UniV2pair testUSDC 6000 WETH 50
        // get weth and approve
        uint wethMaxFee = 200 * 1e18;
        iweth.deposit{value: wethMaxFee}();
        iweth.approve(address(uniV3FlashToV2), wethMaxFee);

        testUsdcAddr = address(testUsdc);
        address wethUsdcUnipoolAddr = IUniswapV2Factory(UNISWAP_V2_FACTORY)
            .createPair(WETH, testUsdcAddr);
        console.log("UniV2 pool setup complete!");
        vm.label(UNISWAP_V2_FACTORY, "UniswapV2Factory");
        vm.label(UNISWAP_V2_ROUTER, "UniswapV2Router");
        vm.label(wethUsdcUnipoolAddr, "WethUsdcUniPool");
        vm.label(WETH, "WETH");
        vm.label(address(testUsdcAddr), "testUSDC");

        testUsdc.mint(address(this), 20000 * 1e6);
        testUsdc.approve(UNISWAP_V2_ROUTER, 10000 * 1e6);
        console.log("testUSDC balance", testUsdc.balanceOf(address(this)));

        // add liquidity to UniV2 pool
        IUniswapV2Router01(UNISWAP_V2_ROUTER).addLiquidityETH{value: 50 ether}(
            testUsdcAddr,
            6_000 * 10 ** testUsdc.decimals(),
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
            "testUSDC balance after creating uniV2pool",
            testUsdc.balanceOf(address(this))
        );

        // create UniV3pool testUSDC 4000 WETH 50 fee 500
        iweth.approve(address(nonfungiblePositionManager), 100 * 1e18);
        testUsdc.approve(address(nonfungiblePositionManager), 10000 * 1e6);
        uniV3Pool = nonfungiblePositionManager
            .createAndInitializePoolIfNecessary(
                testUsdcAddr,
                WETH,
                uniV3fee,
                sqrtPriceX96
            );
        console.log("UniV3 pool setup complete!");
        console.log("UniV3 pool address", uniV3Pool);

        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: testUsdcAddr,
                token1: WETH,
                fee: 500,
                tickLower: MIN_TICK,
                tickUpper: MAX_TICK,
                amount0Desired: amount0ToMint,
                amount1Desired: amount1ToMint,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            });
        console.log("UniV3 pool mint start...");
        (tokenId, liquidity, amount0, amount1) = nonfungiblePositionManager
            .mint(params);
        console.log("UniV3 pool mint complete!");
        console.log(
            "testUSDC balance after creating uniV3pool",
            testUsdc.balanceOf(address(this))
        );
    }

    function testUniswapV3FlashSwap() public {
        console.log("------------------------------");
        console.log("-------------USDC-------------");
        console.log("------------------------------");
        uint usdcBalBefore = testUsdc.balanceOf(address(this));
        console.log("caller USDC balance before", usdcBalBefore);
        uint amountUSDCIntoUniV3Pool = 800 * 1e6;
        uniV3FlashToV2.UniswapV3FlashSwap(
            uniV3Pool,
            testUsdcAddr,
            WETH,
            amountUSDCIntoUniV3Pool
        );
        uint usdcBalAfter = testUsdc.balanceOf(address(this));
        console.log("caller USDC balance after", usdcBalAfter);

        if (usdcBalAfter >= usdcBalBefore) {
            console.log("USDC profit", usdcBalAfter - usdcBalBefore);
        } else {
            console.log("USDC loss", usdcBalBefore - usdcBalAfter);
        }
    }
}
