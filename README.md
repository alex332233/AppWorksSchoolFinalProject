# DEX Arbitrage
Threre are 3+1 contracts in this project:
AlexUniV2toSushiV2Arbitrage: From UniswapV2 Flashswap borrow token and swap at SushiSwap.
AlexUniV2toUniV3Arbitrage: From UniswapV2 Flashswap borrow token and swap at UniswapV3.
AlexV3toV2Arbitrage: From UniswapV3 Flashswap borrow token and swap at UniswapV2.
AlexV3toV2Arbitrage_try: Try to reproduce this transaction[https://etherscan.io/tx/0x4ad48cba36f758b8a0f19dc26e985e82bff85a14e98fa469789ce9430a0c2276]. This one didn't success since there is another transaction[https://etherscan.io/tx/0xcd237c514a57da0de22c02827d65660463426fb1a22aac97959f22b4cead2d31] ahead in the same block to fulfill situation.

Each contract has it's own test. They can be executed by using
```
forge test -vv --fork-url $FORK_URL
```

Coverage can be check by using
```
forge coverage
```
result:
![image](https://github.com/alex332233/AppWorksSchoolFinalProject/assets/99250288/731b5316-450e-4dba-a766-bb28d9c13a21)
