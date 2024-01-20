// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/AlexV3toV2Arbitrage_try.sol";

contract AlexUniswapV3toV2ArbitrageTryTest is Test {
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address private constant TURBO = 0xA35923162C49cF95e6BF26623385eb431ad920D3;

    address private constant UNISWAP_V2_ROUTER =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address[] private path = new address[](2);

    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    uint160 internal constant MAX_SQRT_RATIO =
        1461446703485210103287273052203988822378723970342;

    IWETH private weth = IWETH(WETH);
    IERC20 private turbo = IERC20(TURBO);

    AlexUniswapV3toV2ArbitrageTry private uniV3FlashToV2;

    function setUp() public {
        // uint blockNumber = 18891170;
        // vm.createSelectFork(vm.envString("FORK_URL"), blockNumber);
        // console.log("Block number: ", block.number);
        // uniV3FlashToV2 = new AlexUniswapV3toV2ArbitrageTry();
    }

    function testUniswapV3FlashSwapTurbo() public {
        uint blockNumber = 18891170;
        vm.createSelectFork(vm.envString("FORK_URL"), blockNumber);
        console.log("Block number: ", block.number);
        uniV3FlashToV2 = new AlexUniswapV3toV2ArbitrageTry();
        address pool = 0x7baecE5d47f1BC5E1953FBE0E9931D54DAB6D810;
        // WETH/TURBO 0x7baecE5d47f1BC5E1953FBE0E9931D54DAB6D810
        // WETH/USDC 0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8
        uint amountIntoUniV3Pool = 3494222835789865; // 0.003494352835789865 WETH
        // 19817463299396421665729  // 19,817.463299396421665729 Turbo
        uint poolWethBalance = weth.balanceOf(pool);
        console.log("WETH balance in pool", poolWethBalance);

        // Approve WETH fee
        uint wethMaxFee = 10 * 1e18;
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

        console.log("------------------------------");
        console.log("-------------TURBO------------");
        console.log("------------------------------");
        path[0] = WETH;
        path[1] = TURBO;
        IERC20(WETH).approve(UNISWAP_V2_ROUTER, 3 * 1e18);
        IERC20(WETH).approve(address(pool), 3 * 1e18);
        IUniswapV2Router02(UNISWAP_V2_ROUTER).swapExactTokensForTokens(
            1 * 1e18,
            0,
            path,
            address(this),
            block.timestamp
        )[1];
        turbo.approve(UNISWAP_V2_ROUTER, 40000 * 1e18);
        turbo.approve(address(uniV3FlashToV2), 40000 * 1e18);
        console.log("TURBO balance", IERC20(TURBO).balanceOf(address(this)));

        // // bool zeroForOne = true;
        // // uint160 sqrtPriceLimitX96 = zeroForOne
        // //     ? MIN_SQRT_RATIO + 1
        // //     : MAX_SQRT_RATIO - 1;
        // // uint turboAmountIntoUniV3Pool = 19817874119831491067762; // 0.000034942228351111 TURBO
        // // address uniV3Pool = 0x7baecE5d47f1BC5E1953FBE0E9931D54DAB6D810;
        // // console.log("swap for TURBO");
        // // IUniswapV3Pool(uniV3Pool).swap(
        // //     address(this),
        // //     false, // True token0 address first, token1 address second
        // //     int256(turboAmountIntoUniV3Pool), // user specified how much token to flashswap
        // //     4295128739,
        // //     ""
        // // );
        // // console.log("TURBO balance", turbo.balanceOf(address(this)));
        turbo.approve(address(pool), 40000 * 1e18);
        uint balTurboBefore = turbo.balanceOf(address(this));
        uniV3FlashToV2.UniswapV3FlashSwap(
            pool,
            TURBO,
            WETH,
            30000000000000000000000
        );
        uint balTurboAfter = turbo.balanceOf(address(this));
        if (balTurboAfter >= balTurboBefore) {
            console.log("TURBO profit", balTurboAfter - balTurboBefore);
        } else {
            console.log("TURBO loss", balTurboBefore - balTurboAfter);
        }
    }

    function testV3toV2TryRequires() public {
        uint blockNumber = 18891170;
        vm.createSelectFork(vm.envString("FORK_URL"), blockNumber);
        console.log("Block number: ", block.number);
        uniV3FlashToV2 = new AlexUniswapV3toV2ArbitrageTry();

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
