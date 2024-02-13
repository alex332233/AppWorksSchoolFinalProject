// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "../node_modules/@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
// // import "../node_modules/@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

// import "../node_modules/@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
// import "../node_modules/@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract AlexUniswapV3toV2ArbitragePNL {
    // variable and constant setting
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    uint160 internal constant MAX_SQRT_RATIO =
        1461446703485210103287273052203988822378723970342;
    address private constant UNISWAP_V2_FACTORY =
        0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address private constant UNISWAP_V2_ROUTER =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    IUniswapV2Pair private uniV2PairInterface;
    address private uniV2PairAddress;

    // First, Flash Swap from UniswapV3 and get some token like WETH, USDC, TURBO
    function UniswapV3FlashSwap(
        address uniV3Pool,
        address token0, // flashswap input token
        address token1, // flashswap output token
        uint256 amountIntoUniV3Pool // swap input amount // uint24 fee // swap fee
    ) external {
        console.log("UniswapV3FlashSwap start...");
        bool zeroForOne = token0 < token1; // zeroForone if token0 address is smaller than token1 address
        // zeroForOne is not for token flow direction, it's for UniswapV3 pool address
        // no matter True or False, we swap token0 to token1 at UniswapV3
        uint160 sqrtPriceLimitX96 = zeroForOne
            ? MIN_SQRT_RATIO + 1
            : MAX_SQRT_RATIO - 1;

        bytes memory data = abi.encode(
            msg.sender,
            uniV3Pool,
            token0,
            token1,
            amountIntoUniV3Pool,
            // fee,
            zeroForOne
            // ... add more arguments here if needed
        );
        console.log("token0 in callback data: ", token0);
        console.log("token1 in callback data: ", token1);

        IUniswapV3Pool pool = IUniswapV3Pool(uniV3Pool);
        pool.swap(
            address(this),
            zeroForOne, // True token0 address first, token1 address second
            int256(amountIntoUniV3Pool), // user specified how much token to flashswap
            sqrtPriceLimitX96,
            data
        );
        console.log("----------flashswap balance check----------");
        console.log(
            "balanceOf token0",
            IERC20(token0).balanceOf(address(this))
        );
        console.log(
            "balanceOf token1",
            IERC20(token1).balanceOf(address(this))
        );
    }

    // Second, in UniswapV3 callback function, swap token at UniswapV2 and get some other token
    // note when in callback,
    // amount0 stands for token1 in flashswap function,
    // amount1 stands for token0 in flashswap function
    function uniswapV3SwapCallback(
        int amount0,
        int amount1,
        bytes calldata data
    ) external {
        console.log("uniswapV3SwapCallback start...");
        (
            address caller,
            address uniV3Pool,
            address uniV3token0, // in this function amount1
            address uniV3token1,
            uint256 amountIntoUniV3Pool,
            // uint24 fee,
            bool zeroForOne
        ) = abi.decode(
                data,
                (address, address, address, address, uint256, /*uint24,*/ bool)
            );
        console.log("zeroForOne address check:", zeroForOne);
        // if zeroForOne is True, amount0 related to token0, amount1 related to token1
        // if zeroForOne is False, amount0 related to token1, amount1 related to token0
        console.log("check amount0: ", uint(-amount0)); // while zeroFor One False, this line is false
        console.log(
            "balanceOf",
            uniV3token0,
            " :",
            IERC20(uniV3token0).balanceOf(address(this))
        ); // uniV3token0 balance correct
        console.log("check amount1: ", uint(amount1));
        console.log(
            "balanceOf",
            uniV3token1,
            " :",
            IERC20(uniV3token1).balanceOf(address(this))
        ); // uniV3token1 balance correct
        console.log("uniV3token0 address: ", uniV3token0);
        console.log("uniV3token1 address: ", uniV3token1);

        console.log("msg.sender check: ", msg.sender);
        console.log("uniV3Pool address: ", uniV3Pool);
        require(msg.sender == address(uniV3Pool), "Unauthorized");

        // Swap token at UniswapV2
        // First, get UniswapV2 pair address
        uniV2PairAddress = IUniswapV2Factory(UNISWAP_V2_FACTORY).getPair(
            uniV3token0,
            uniV3token1
        );
        console.log("uniV2PairAddress: ", uniV2PairAddress);
        uniV2PairInterface = IUniswapV2Pair(uniV2PairAddress);

        uint amountBorrowed;
        address[] memory path;
        if (zeroForOne) {
            console.log("zeroForOne is True, get in if");
            amountBorrowed = uint(-amount1); //amount1 is borrowed from UniswapV3, so V3 give it a negative value
            console.log("amountBorrowed: ", amountBorrowed);
            // IERC20(uniV3token0).approve(UNISWAP_V2_ROUTER, amountBorrowed);
            // IERC20(uniV3token0).approve(uniV2PairAddress, amountBorrowed);
            // path = getPathForTokens(uniV3token0, uniV3token1); // borrow token1, so swap token1 to token0 at UniswapV2
            // console.log("path from: ", path[0]);
            // console.log("path to: ", path[1]);
        } else {
            console.log("zeroForOne is False, get in else");
            amountBorrowed = uint(-amount0); // or balanceOf(uniV3token1)
            console.log("amountBorrowed: ", amountBorrowed);
            // IERC20(uniV3token1).approve(UNISWAP_V2_ROUTER, amountBorrowed);
            // IERC20(uniV3token1).approve(uniV2PairAddress, amountBorrowed);
            // path = getPathForTokens(uniV3token1, uniV3token0);
            // console.log("path from: ", path[0]);
            // console.log("path to: ", path[1]);
        }
        console.log("amountBorrowed: ", amountBorrowed);
        console.log(
            "balanceOf",
            uniV3token0,
            " :",
            IERC20(uniV3token0).balanceOf(address(this))
        );
        console.log(
            "balanceOf",
            uniV3token1,
            " :",
            IERC20(uniV3token1).balanceOf(address(this))
        );
        console.log("router: ", UNISWAP_V2_ROUTER);
        IERC20(uniV3token1).approve(UNISWAP_V2_ROUTER, type(uint).max);
        IERC20(uniV3token1).approve(uniV2PairAddress, type(uint).max);
        path = getPathForTokens(uniV3token1, uniV3token0);
        console.log("v2 swap path from: ", path[0]);
        console.log("v2 swap path to: ", path[1]);
        console.log("address(this): ", address(this));
        // Second, swap amountBorrowed token at UniswapV2
        // Specify the exact input amount (amountBorrowed) and minimum output amount

        uint[] memory uniV2AmountsOut = IUniswapV2Router02(UNISWAP_V2_ROUTER)
            .swapExactTokensForTokens(
                amountBorrowed,
                0,
                path,
                address(this),
                block.timestamp
            );
        // note
        // 38ed1739: swapExactTokensForTokens(uint256,uint256,address[],address,uint256)
        // 0902f1ac: getReserves()
        // 23b872dd: transferFrom

        uint256 amountFromUniV2Pair = uniV2AmountsOut[
            uniV2AmountsOut.length - 1 // actually 1 for two tokens
        ];
        console.log("amountFromUniV2Pair: ", amountFromUniV2Pair);

        // Thitd, repay / transfer token back to UniswapV3 Pool
        if (amountFromUniV2Pair >= amountIntoUniV3Pool) {
            console.log("this transaction is profitable");
            uint profit = amountFromUniV2Pair - amountIntoUniV3Pool;
            IERC20(uniV3token0).transfer(
                address(uniV3Pool),
                amountIntoUniV3Pool
            );
            IERC20(uniV3token0).transfer(caller, profit);
        } else {
            uint loss = amountIntoUniV3Pool - amountFromUniV2Pair;
            console.log("this transaction loss", loss);
            IERC20(uniV3token0).transferFrom(caller, address(this), loss);
            console.log("transfered loss from caller");
            IERC20(uniV3token0).transfer(
                address(uniV3Pool),
                amountIntoUniV3Pool
            );
            console.log("repayed to UniV3Pool");
        }
    }

    function getPathForTokens(
        address tokenA,
        address tokenB
    ) private pure returns (address[] memory) {
        // path is from input token to output token
        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;
        return path;
    }
}

// interface IUniswapV3Pool {
//     function swap(
//         address recipient,
//         bool zeroForOne,
//         int amountSpecified,
//         uint160 sqrtPriceLimitX96,
//         bytes calldata data
//     ) external returns (int amount0, int amount1);
// }

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
}

// interface IUniswapV2Pair {
//     function swap(
//         uint amount0Out,
//         uint amount1Out,
//         address to,
//         bytes calldata data
//     ) external;
// }

// interface IUniswapV2Factory {
//     function getPair(
//         address tokenA,
//         address tokenB
//     ) external view returns (address pair);
// }

// interface IUniswapV2Router02 {
//     function swapExactTokensForTokens(
//         uint amountIn,
//         uint amountOutMin,
//         address[] calldata path,
//         address to,
//         uint deadline
//     ) external returns (uint[] memory amounts);
// }
