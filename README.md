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

![image](https://github.com/alex332233/AppWorksSchoolFinalProject/assets/99250288/731b5316-450e-4dba-a766-bb28d9c13a21)
![image](https://github.com/alex332233/AppWorksSchoolFinalProject/assets/99250288/bfe4d4c5-7299-4865-a090-98b6273680f2)
(All the tests of lines and functions made in this project are passed. The tests with node_modules prefixed are packages from Openzeppelin and Uniswap which do not have to be tested.)
