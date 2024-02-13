// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract AlexUniV2toSushiV2ArbitragePNL {
    // variable and constant setting
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    uint160 internal constant MAX_SQRT_RATIO =
        1461446703485210103287273052203988822378723970342;
    address private constant UNISWAP_V2_FACTORY =
        0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    IUniswapV2Pair private uniV2PairInterface;
    address private uniV2PairAddress;
    address[] private pathA = new address[](2);
    address[] private pathB = new address[](2);
    address private token;
    address private otherToken;

    // First, Flash Swap from UniswapV3 and get some token like WETH, USDC, TURBO
    function UniswapV2FlashSwap(
        address _tokenBorrow,
        address _tokenRepay,
        address _sourceRouter,
        address _targetRouter,
        // uint256 _tokenBorrowAmount
        uint256 _repayAmount
    ) external {
        console.log("UniswapV2FlashSwap start...");

        address pairAddress = IUniswapV2Factory(UNISWAP_V2_FACTORY).getPair(
            _tokenBorrow,
            _tokenRepay
        );
        require(pairAddress != address(0), "This pool does not exist");

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

        bytes memory data = abi.encode(
            msg.sender,
            _sourceRouter,
            _targetRouter,
            pairAddress
            // _tokenBorrow
        );

        IUniswapV2Pair pool = IUniswapV2Pair(pairAddress);
        console.log("flashswap start...");
        pool.swap(
            _tokenBorrow == token0 ? _tokenBorrowAmount : 0,
            _tokenBorrow == token1 ? _tokenBorrowAmount : 0,
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
            address caller,
            address sourceRouter,
            address targetRouter,
            address pairAddress // uint256 repayAmount
        ) = abi.decode(_data, (address, address, address, address /*uint256*/));
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
        IERC20(token).approve(targetRouter, amountToken);

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

        uint256 amountReceived = IUniswapV2Router02(targetRouter)
            .swapExactTokensForTokens(
                amountToken,
                0,
                pathA,
                address(this),
                block.timestamp
            )[1];
        console.log("amountReceived: ", amountReceived);
        otherToken = _amount0 == 0 ? token0 : token1;
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
