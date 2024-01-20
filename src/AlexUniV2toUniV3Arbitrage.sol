// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "../node_modules/@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
// // import "../node_modules/@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

// import "../node_modules/@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
// import "../node_modules/@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

contract AlexUniV2toUniV3Arbitrage {
    // variable and constant setting
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    uint160 internal constant MAX_SQRT_RATIO =
        1461446703485210103287273052203988822378723970342;
    address private constant UNISWAP_V2_FACTORY =
        0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    ISwapRouter constant uniV3Router =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    IUniswapV2Pair private uniV2PairInterface;
    address private uniV2PairAddress;

    address private tokenBorrow;
    address private tokenRepay;

    address[] private pathA = new address[](2);
    address[] private pathB = new address[](2);
    address private token;
    address private otherToken;
    address private caller;

    // First, Flash Swap from UniswapV3 and get some token like WETH, USDC, TURBO
    function UniswapV2FlashSwap(
        address _tokenBorrow,
        address _tokenRepay,
        address _sourceRouter,
        // address _targetRouter,
        // uint256 _tokenBorrowAmount
        uint256 _repayAmount,
        address uniV3Pool,
        uint24 uniV3Fee
    ) external {
        console.log("UniswapV2FlashSwap start...");

        address pairAddress = IUniswapV2Factory(UNISWAP_V2_FACTORY).getPair(
            _tokenBorrow,
            _tokenRepay
        );
        require(pairAddress != address(0), "This pool does not exist");

        tokenBorrow = _tokenBorrow;
        tokenRepay = _tokenRepay;

        address token0 = IUniswapV2Pair(pairAddress).token0();
        address token1 = IUniswapV2Pair(pairAddress).token1();

        address[] memory path = new address[](2);
        // path is from tokenRepay swap to tokenBorrow
        path[1] = _tokenBorrow;
        path[0] = _tokenRepay;

        uint256 _tokenBorrowAmount = IUniswapV2Router02(_sourceRouter)
            .getAmountsOut(_repayAmount, path)[1];
        console.log("tokenBorrow from univ2: ", _tokenBorrow);
        console.log("tokenBorrowAmount from univ2: ", _tokenBorrowAmount);
        console.log(
            "this contract balance: ",
            IERC20(_tokenBorrow).balanceOf(address(this))
        );

        /////////////////
        // encode data //
        /////////////////
        caller = msg.sender;
        bytes memory data = abi.encode(
            // msg.sender,
            _sourceRouter,
            // _targetRouter,
            pairAddress,
            uniV3Pool,
            uniV3Fee
        );

        IUniswapV2Pair pool = IUniswapV2Pair(pairAddress);
        console.log("flashswap start...");
        pool.swap(
            tokenBorrow == token0 ? _tokenBorrowAmount : 0,
            tokenBorrow == token1 ? _tokenBorrowAmount : 0,
            address(this),
            data
        );
        console.log("----------flashswap balance check----------");
        console.log(
            "contract balanceOf token0",
            IERC20(token0).balanceOf(address(this))
        );
        console.log(
            "contract balanceOf token1",
            IERC20(token1).balanceOf(address(this))
        );
    }

    // Second, in UniswapV2 callback function, swap token at "other"swapV2 and get the other token
    function uniswapV2Call(
        address /*_sender*/,
        uint256 _amount0,
        uint256 _amount1,
        bytes calldata _data
    ) external {
        console.log("uniswapV2SwapCallback start...");

        (
            // address caller,
            address sourceRouter,
            // address targetRouter,
            address pairAddress, // uint256 repayAmount
            address uniV3Pool,
            uint24 uniV3Fee
        ) = abi.decode(
                _data,
                (/*address,*/ address /*address*/, address, address, uint24)
            );
        require(msg.sender == pairAddress, "Not from the right pool");

        uint256 amountToken = _amount0 == 0 ? _amount1 : _amount0;

        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
        address token0 = pair.token0();
        address token1 = pair.token1();

        pathA[0] = pathB[1] = _amount0 == 0 ? token1 : token0;
        pathA[1] = pathB[0] = _amount0 == 0 ? token0 : token1;

        token = _amount0 == 0 ? token1 : token0;
        console.log(
            "this contract balance of token: ",
            IERC20(token).balanceOf(address(this))
        );
        IERC20(token).approve(uniV3Pool, amountToken);

        console.log("token0", token0);
        console.log(
            "balanceOf token0: ",
            IERC20(token0).balanceOf(address(this))
        ); // balance check
        console.log("token1", token1);
        console.log(
            "balanceOf token1: ",
            IERC20(token1).balanceOf(address(this))
        ); // balance check

        console.log("msg.sender check: ", msg.sender);
        console.log("caller Pool address: ", pairAddress);

        uint256 amountRequired = IUniswapV2Router02(sourceRouter).getAmountsIn(
            amountToken,
            pathB
        )[0];
        console.log("univ2 repaytoken: ", address(pathB[0]));
        console.log("amountRequired: ", amountRequired);

        /////////////
        //UniV3Swap//
        /////////////
        console.log("UniV3Swap start...");
        otherToken = _amount0 == 0 ? token0 : token1;
        // bool zeroForOne = token < otherToken;
        // console.log("zeroForOne: ", zeroForOne);
        // uint160 sqrtPriceLimitX96 = zeroForOne
        //     ? MIN_SQRT_RATIO + 1
        //     : MAX_SQRT_RATIO - 1;

        // (int256 amount0, int256 amount1) = IUniswapV3Pool(uniV3Pool).swap(
        //     address(this),
        //     zeroForOne,
        //     int(amountToken),
        //     sqrtPriceLimitX96,
        //     ""
        // );
        uint amountReceived = _swap(token, otherToken, uniV3Fee, amountToken);
        // if (zeroForOne) {
        //     amountReceived = uint(-amount1);
        // } else {
        //     amountReceived = uint(-amount0);
        // }

        // require(
        //     amountReceived >= amountRequired,
        //     "Not enough to repay flashswap"
        // );
        // IERC20 otherToken = IERC20(_amount0 == 0 ? token0 : token1);
        console.log("otherToken: ", address(otherToken));
        console.log("amountReceived: ", amountReceived);
        console.log(
            "contract balance: ",
            IERC20(otherToken).balanceOf(address(this))
        );
        console.log("amountRequired: ", amountRequired);

        if (amountReceived >= amountRequired) {
            console.log("this transaction is profitable");
            uint profit = amountReceived - amountRequired;
            IERC20(otherToken).transfer(address(pairAddress), amountRequired);
            IERC20(otherToken).transfer(caller, profit);
        } else {
            console.log("this transaction loss");
            uint loss = amountRequired - amountReceived;
            IERC20(otherToken).transferFrom(caller, address(this), loss);
            IERC20(otherToken).transfer(address(pairAddress), amountRequired);
        }

        // code note
        // 70a08231: balanceOf(address)
    }

    function _swap(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint amountIn
    ) private returns (uint amountOut) {
        IERC20(tokenIn).approve(address(uniV3Router), amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: fee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        amountOut = uniV3Router.exactInputSingle(params);
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
}

// interface IUniswapV2Pair {
//     function swap(
//         uint amount0Out,
//         uint amount1Out,
//         address to,
//         bytes calldata data
//     ) external;
// }

interface IUniswapV2Factory {
    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address pair);
}

// interface IUniswapV2Router02 {
//     function swapExactTokensForTokens(
//         uint amountIn,
//         uint amountOutMin,
//         address[] calldata path,
//         address to,
//         uint deadline
//     ) external returns (uint[] memory amounts);
// }
