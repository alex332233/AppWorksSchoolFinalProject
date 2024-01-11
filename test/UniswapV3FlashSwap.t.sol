// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/UniswapV3FlashSwap.sol";

contract UniswapV3FlashSwapTest is Test {
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant TURBO = 0xA35923162C49cF95e6BF26623385eb431ad920D3;
    // address private constant univ3pool =
    //     0x7baecE5d47f1BC5E1953FBE0E9931D54DAB6D810;
    address private constant univ2pool =
        0x455d4d19aCA31C7530D75a32f98cf28d98365587;
    address user1 = makeAddr("User1");

    IWETH private weth = IWETH(WETH);
    IERC20 private turbo = IERC20(TURBO);
    UniswapV3FlashSwap private uniFlashSwapContract;

    function setUp() public {
        vm.createSelectFork(vm.envString("FORK_URL"), 18891170);
        deal(user1, 1e18);
        uniFlashSwapContract = new UniswapV3FlashSwap();
    }

    function testFlashSwap() public {
        // TURBO / WETH pool
        address univ3pool = 0x7baecE5d47f1BC5E1953FBE0E9931D54DAB6D810;
        // uint24 fee0 = 3000;
        // address pool1 = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;
        uint24 fee1 = 3000;
        uint256 amountIn = 19817473602235238009479; // 19,817.473602235238009479 Turbo

        // Approve WETH fee
        uint wethMaxFee = 1e18;
        weth.deposit{value: wethMaxFee}();
        weth.approve(address(uniFlashSwapContract), wethMaxFee);

        uint balBefore = weth.balanceOf(address(this));
        console.log("WETH balance before", balBefore);
        uniFlashSwapContract.flashSwap(univ3pool, fee1, WETH, TURBO, amountIn);
        uint balAfter = weth.balanceOf(address(this));
        console.log("WETH balance after", balAfter);

        if (balAfter >= balBefore) {
            console.log("WETH profit", balAfter - balBefore);
        } else {
            console.log("WETH loss", balBefore - balAfter);
        }
    }
}
