// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/AlexV3toV2Arbitrage_PNL.sol";
import {IUniswapV2Router01} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {TestERC20} from "./helper/TestERC20.sol";

contract AlexUniswapV3toV2ArbitrageTest is Test {
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address private constant UNISWAP_V2_ROUTER =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address[] private path = new address[](2);

    IWETH private weth = IWETH(WETH);
    IERC20 private usdc = IERC20(USDC);

    AlexUniswapV3toV2ArbitragePNL private uniV3FlashToV2;
    ///////////////////////
    //for test pool setup//
    ///////////////////////
    TestERC20 public testUsdc;
    IWETH public iweth = IWETH(WETH); // iweth = weth
    address public testUsdcAddr;
    IUniswapV2Factory public uniswapV2Factory;
    IUniswapV2Router01 public uniswapV2Router;
    IUniswapV2Pair public wethUsdcPool;

    uint public tokenId;
    uint public liquidity;
    uint public amount0;
    uint public amount1;

    address private constant UNISWAP_V2_FACTORY =
        0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;

    // create UniV3pool
    // INonfungiblePositionManager
    INonfungiblePositionManager public nonfungiblePositionManager =
        INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    address uniV3PoolCreated;
    uint24 uniV3fee = 500;
    uint256 amount0ToMint = 5000 * 1e6;
    uint256 amount1ToMint = 1 * 1e18;
    // uint160 sqrtPriceX96 = 2.7201717 * 1e31; // sqrt(amount0ToMint/amount1ToMint) * 2 ** 96
    uint160 sqrtPriceX96 = 5.6022771 * 1e30; // manaul test
    int24 constant ticknow = 85176; // price ~ 5000
    int24 constant tickLower = 84220; // price ~ 4545
    int24 constant tickUpper = 86130; // price ~ 5500

    function setUp() public {
        vm.createSelectFork(vm.envString("FORK_URL") /*, 18995573*/);
        console.log("deploy uniV3FlashToUniV2");
        uniV3FlashToV2 = new AlexUniswapV3toV2ArbitragePNL();
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
        uniV3PoolCreated = nonfungiblePositionManager
            .createAndInitializePoolIfNecessary(
                testUsdcAddr,
                WETH,
                uniV3fee,
                sqrtPriceX96
            );
        console.log("UniV3 pool setup complete!");
        console.log("UniV3 pool address", uniV3PoolCreated);

        (
            uint160 checkSqrtPriceX96,
            int24 currentTick,
            ,
            ,
            ,
            ,

        ) = IUniswapV3Pool(uniV3PoolCreated).slot0();

        // tick range calculation
        checkTick(currentTick);
        // int24 tickLower = currentTick - (919);
        checkTick(tickLower);
        // int24 tickUpper = currentTick + (571);
        checkTick(tickUpper);

        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: testUsdcAddr,
                token1: WETH,
                fee: 500,
                tickLower: tickLower,
                tickUpper: tickUpper,
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

        // check weth and USDC reserve in uniV3pool
        uint token0_amount = liquidity / (checkSqrtPriceX96 / (2 ** 96));
        uint token1_amount = liquidity * (checkSqrtPriceX96 / (2 ** 96));
        console.log("token0/usdc_amount", token0_amount);
        console.log("token1/weth_amount", token1_amount);
        console.log("-----------------------------");
        console.log(
            "usdc balance of uniV3pool",
            testUsdc.balanceOf(uniV3PoolCreated)
        );
        console.log(
            "weth balance of uniV3pool",
            iweth.balanceOf(uniV3PoolCreated)
        );
    }

    function testUniswapV3FlashSwapProfit() public {
        console.log("------------------------------");
        console.log("-------------weth-------------");
        console.log("------------------------------");
        uint amountIntoUniV3Pool = 2 * 1e18;
        uint balBefore = iweth.balanceOf(address(this));
        uniV3FlashToV2.UniswapV3FlashSwap(
            uniV3PoolCreated,
            WETH,
            testUsdcAddr,
            amountIntoUniV3Pool
        );
        uint balAfter = iweth.balanceOf(address(this));

        if (balAfter >= balBefore) {
            console.log("WETH profit", balAfter - balBefore);
        } else {
            console.log("WETH loss", balBefore - balAfter);
        }
    }

    function testUniswapV3FlashSwap() public {
        // vm.createSelectFork(vm.envString("FORK_URL") /*, 18995573*/);
        // uniV3FlashToV2 = new AlexUniswapV3toV2ArbitragePNL();
        address pool = 0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8;
        uint amountIntoUniV3Pool = 2 * 1e18;

        // Approve WETH fee
        // uint wethMaxFee = 10 * 1e18;
        // weth.deposit{value: wethMaxFee}();
        // weth.approve(address(uniV3FlashToV2), wethMaxFee);

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
        uniV3FlashToV2 = new AlexUniswapV3toV2ArbitragePNL();

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

    event LogCurrentTick(int24 tick);

    function checkTick(int24 tick) public {
        emit LogCurrentTick(tick);
    }
}
