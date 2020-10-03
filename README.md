# Unilayer Launchpad Smart contracts (Still in progress, not use)


# Launchpad Flow

1 - Token is created

2 - Launchpad contract is created

3 - Transfer all tokens to Launchpad contract

4 - Start Launchpad Sale

Fields needed:

- priceUni - Price of initial Uniswap Liquidity
- price  - Price for sale
- owner - owner which receive liquidity tokens, 
- teamWallet - wallet which receives the raised ETH
- softCap - Minimum soft cap to finish sale, if not reached sale is refunded
- maxCap - Maximum cap to finish sale, it will sold out
- liquidityPercent - Percentage destined to Uniswap Liquidity, max is 30 %, pass value as 30 * 10000
- teamPercent - Percentage destined to Team, max depends on liquidity value, pass value as 30 * 10000
- uint256 end -  End time of sale
- uint256 start - Start time of sale
- uint256 releaseTime - time for withraw LP tokens

 NOTE: Price needs to be passed inverted multiplied by a BASE of 100000, for instance if price is 0.005 per ETH you pass as parameter (1/0.005)*BASE