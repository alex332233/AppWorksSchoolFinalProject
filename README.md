# DEX Arbitrage
There are 3 contracts in this project:  
-AlexUniV2toSushiV2Arbitrage: From UniswapV2 Flashswap borrow a token and swap at SushiSwap.  
-AlexUniV2toUniV3Arbitrage: From UniswapV2 Flashswap borrow the token and swap at UniswapV3.  
-AlexV3toV2Arbitrage: From UniswapV3 Flashswap borrows the token and swaps at UniswapV2.  

Each contract has its test. They can be executed by using
```
forge test -vv --fork-url $FORK_URL
```

Coverage can be checked by using
```
forge coverage
```
result:

![image](https://github.com/alex332233/AppWorksSchoolFinalProject/assets/99250288/c80192e0-65a2-42e4-93c3-44a29a03f52b)

(All the tests of lines and functions made in this project are passed. The tests with node_modules prefixed are packages from Openzeppelin and Uniswap which do not have to be tested.)
