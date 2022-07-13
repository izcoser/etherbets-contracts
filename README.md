Hardhat contract development environment for [Etherbets](https://github.com/izcoser/etherbets).

Current work in progress available at: https://etherbets.org/

# To do

- [x] Create Aggregator contract for Sports Bets - Done. Aggregate results using reports from [TheRundown](https://market.link/nodes/TheRundown/integrations) and [SportsDataIO](https://market.link/nodes/SportsDataIO/integrations). This contract accepts bets on home and away team, then fetches results from both providers and pays out whoever bet on the winning team.

- [ ] Add events to all three betting apps. Currently only lotteries are emitting events.
