// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/AlexUniV2toUniV3Arbitrage_profit.sol";
// uniswap utils
import {IUniswapV2Router01} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
// import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
// import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {TestERC20} from "./helper/TestERC20.sol";

contract AlexUniV2toUniV3ArbitrageProfitTest is Test {
    // create UniV2pair testUSDC 4000 WETH 50 settings
    TestERC20 public testUsdc;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    IWETH public iweth = IWETH(WETH);
    address public testUsdcAddr;
    IUniswapV2Factory public uniswapV2Factory;
    IUniswapV2Router01 public uniswapV2Router;
    IUniswapV2Pair public wethUsdcPool;
    int24 constant MIN_TICK = -887272;
    int24 constant MAX_TICK = 887272;

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

    // borrow weth from univ2 and swap to univ3

    AlexUniV2toUniV3ArbitrageProfit private uniV2FlashToUniV3;

    address uniV3Pool;
    uint24 uniV3fee = 500;
    uint160 sqrtPriceX96 = 1771580069046490802230235074;

    // WETH/USDC V3 0.05 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640

    function setUp() public {
        /////////
        //setUp//
        /////////
        vm.createSelectFork(vm.envString("FORK_URL") /*, 18995573*/);
        console.log("deploy uniV2FlashToSushiV2");
        uniV2FlashToUniV3 = new AlexUniV2toUniV3ArbitrageProfit();
        console.log("uniV2FlashToUniV3 deployed!");

        //////////////////
        //add pool setup//
        //////////////////
        console.log("pool setup start...");
        // testWeth = new TestWETH9();
        testUsdc = new TestERC20("AlextestUSD Coin", "AlextestUSDC", 5);

        // create UniV2pair testUSDC 4000 WETH 50
        // get weth and approve
        uint wethMaxFee = 200 * 1e18;
        iweth.deposit{value: wethMaxFee}();
        iweth.approve(address(uniV2FlashToUniV3), wethMaxFee);

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
            4_000 * 10 ** testUsdc.decimals(),
            0,
            0,
            address(this),
            block.timestamp
        );
        (uint256 token0Reserve, uint256 token1Reserve, ) = IUniswapV2Pair(
            wethUsdcUnipoolAddr
        ).getReserves();
        console.log("wethUsdcUnipool weth reserve", token0Reserve);
        console.log("wethUsdcUnipool usdc reserve", token1Reserve);

        // create UniV3pool testUSDC 6000 WETH 50 fee 500
        iweth.approve(address(nonfungiblePositionManager), 100 * 1e18);
        testUsdc.approve(address(nonfungiblePositionManager), 20000 * 1e6);
        uniV3Pool = nonfungiblePositionManager
            .createAndInitializePoolIfNecessary(
                testUsdcAddr,
                WETH,
                uniV3fee,
                sqrtPriceX96
            );
        console.log("UniV3 pool setup complete!");

        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: testUsdcAddr,
                token1: WETH,
                fee: 500,
                tickLower: MIN_TICK,
                tickUpper: MAX_TICK,
                amount0Desired: 6000 * 1e6,
                amount1Desired: 50 * 1e18,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            });
        (tokenId, liquidity, amount0, amount1) = nonfungiblePositionManager
            .mint(params);
        console.log("UniV3 pool mint complete!");
    }

    function testUniswapV2FlashSwap() public {
        //////////////
        //test start//
        //////////////
        console.log("------------------------------");
        console.log("-------------USDC-------------");
        console.log("------------------------------");
        uint usdcBalBefore = testUsdc.balanceOf(address(this));
        console.log("caller USDC balance before", usdcBalBefore);
        uint repayUSDCAmountToUniV2 = 800 * 1e6;
        uniV2FlashToUniV3.UniswapV2FlashSwap(
            WETH, // borrow from UniV2
            testUsdcAddr, // repay to UniV2, profit or loss
            UNISWAP_V2_ROUTER,
            repayUSDCAmountToUniV2,
            uniV3Pool,
            uniV3fee
        );
        uint usdcBalAfter = testUsdc.balanceOf(address(this));
        console.log("caller USDC balance after", usdcBalAfter);

        if (usdcBalAfter >= usdcBalBefore) {
            console.log("USDC profit", usdcBalAfter - usdcBalBefore);
        } else {
            console.log("USDC loss", usdcBalBefore - usdcBalAfter);
        }
    }

    // function testUniV2toUniV3Requires() public {
    //     /////////
    //     //setUp//
    //     /////////
    //     vm.createSelectFork(vm.envString("FORK_URL") /*, 18995573*/);
    //     uniV2FlashToUniV3 = new AlexUniV2toUniV3Arbitrage();
    //     // Approve WETH fee
    //     uint wethMaxFee = 10e18;
    //     weth.deposit{value: wethMaxFee}();
    //     weth.approve(address(uniV2FlashToUniV3), wethMaxFee);

    //     // get some USDC
    //     path[0] = WETH;
    //     path[1] = USDC;
    //     IERC20(WETH).approve(UNISWAP_V2_ROUTER, 1e18);
    //     IUniswapV2Router02(UNISWAP_V2_ROUTER).swapExactTokensForTokens(
    //         1e18,
    //         0,
    //         path,
    //         address(this),
    //         block.timestamp
    //     )[1];
    //     usdc.approve(address(uniV2FlashToUniV3), 20000 * 1e6);
    //     console.log("USDC balance", IERC20(USDC).balanceOf(address(this)));

    //     //////////////
    //     //test start//
    //     //////////////
    //     vm.expectRevert("This pool does not exist");
    //     uint repayAmountToUniV2 = 2 * 1e18;
    //     uniV2FlashToUniV3.UniswapV2FlashSwap(
    //         address(0), // borrow from UniV2
    //         address(0), // repay to UniV2, profit or loss
    //         UNISWAP_V2_ROUTER,
    //         repayAmountToUniV2,
    //         uniV3Pool,
    //         uniV3fee
    //     );

    //     vm.expectRevert("Not from the right pool");
    //     bytes memory data = abi.encode(
    //         address(this),
    //         WETH,
    //         WETH,
    //         500
    //         // _tokenBorrow
    //     );
    //     uniV2FlashToUniV3.uniswapV2Call(address(this), 0, 0, data);
    // }

    // // self-created funciton for creating a pool
    // function createAndInitializePoolIfNecessary(
    //     address tokenA,
    //     address tokenB,
    //     uint24 fee,
    //     uint160 sqrtPriceX96
    // ) external payable returns (address pool) {
    //     pool = IUniswapV3Factory(factory).getPool(tokenA, tokenB, fee);

    //     if (pool == address(0)) {
    //         pool = IUniswapV3Factory(factory).createPool(tokenA, tokenB, fee);
    //         IUniswapV3Pool(pool).initialize(sqrtPriceX96);
    //     } else {
    //         (uint160 sqrtPriceX96Existing, , , , , , ) = IUniswapV3Pool(pool).slot0();
    //         if (sqrtPriceX96Existing == 0) {
    //             IUniswapV3Pool(pool).initialize(sqrtPriceX96);
    //         }
    //     }
}
