// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../node_modules/@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract UniswapV3FlashSwap {
    ISwapRouter constant router =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IUniswapV2Router02 public routerV2 =
        IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    uint160 internal constant MAX_SQRT_RATIO =
        1461446703485210103287273052203988822378723970342;

    // Example WETH/USDC
    // Sell WETH high      -> Buy WETH low        -> WETH profit
    // WETH in -> USDC out -> USDC in -> WETH out -> WETH profit
    event Log(string message);

    function flashSwap(
        address pool0,
        uint24 fee1,
        address tokenIn,
        address tokenOut,
        uint amountIn
    ) external {
        emit Log("flashSwap start");
        bool zeroForOne = tokenIn < tokenOut;
        uint160 sqrtPriceLimitX96 = zeroForOne
            ? MIN_SQRT_RATIO + 1
            : MAX_SQRT_RATIO - 1;
        bytes memory data = abi.encode(
            msg.sender,
            pool0,
            fee1, // fee1 is for buy token; fee0 is for sell token
            tokenIn,
            tokenOut,
            amountIn,
            zeroForOne
        );

        IUniswapV3Pool(pool0).swap(
            address(this),
            zeroForOne,
            int(amountIn),
            sqrtPriceLimitX96,
            data
        );
    }

    // implement arbitrage logic here
    function uniswapV3SwapCallback(
        int amount0,
        int amount1,
        bytes calldata data
    ) external {
        (
            address caller,
            address pool0,
            uint24 fee1,
            address tokenIn,
            address tokenOut,
            uint amountIn,
            bool zeroForOne
        ) = abi.decode(
                data,
                (address, address, uint24, address, address, uint, bool)
            );

        require(msg.sender == address(pool0), "not authorized");

        uint amountOut;
        if (zeroForOne) {
            amountOut = uint(-amount1);
        } else {
            amountOut = uint(-amount0);
        }

        uint buyBackAmount = _swap(tokenOut, tokenIn, fee1, amountOut);

        // Repay the flash loan
        IERC20(tokenIn).approve(address(pool0), amountIn);
        IUniswapV3Pool(pool0).swap(
            address(this),
            false,
            int(amountIn),
            uint160(0),
            bytes("")
        );

        if (buyBackAmount >= amountIn) {
            uint profit = buyBackAmount - amountIn;
            IERC20(tokenIn).transfer(address(pool0), amountIn);
            IERC20(tokenIn).transfer(caller, profit);
        } else {
            uint loss = amountIn - buyBackAmount;
            IERC20(tokenIn).transferFrom(caller, address(this), loss);
            IERC20(tokenIn).transfer(address(pool0), amountIn);
        }
    }

    function _swap(
        address tokenIn,
        address tokenOut,
        uint24 /*fee*/,
        uint amountIn
    ) private returns (uint amountOut) {
        IERC20(tokenIn).approve(address(routerV2), amountIn);
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        uint[] memory amounts = routerV2.getAmountsOut(amountIn, path);
        uint amountOutMin = (amounts[1] * 99) / 100; // Set slippage tolerance to 1%

        routerV2.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            address(this),
            block.timestamp
        );

        amountOut = IERC20(tokenOut).balanceOf(address(this));
    }
}

interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint deadline;
        uint amountIn;
        uint amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint amountOut);
}

interface IUniswapV3Pool {
    function swap(
        address recipient,
        bool zeroForOne,
        int amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int amount0, int amount1);
}

interface IERC20 {
    function totalSupply() external view returns (uint);

    function balanceOf(address account) external view returns (uint);

    function transfer(address recipient, uint amount) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint);

    function approve(address spender, uint amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}

interface IWETH is IERC20 {
    function deposit() external payable;

    function withdraw(uint amount) external;

    function balanceOf(address account) external view returns (uint);
}
