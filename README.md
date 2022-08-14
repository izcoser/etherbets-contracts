Hardhat contract development environment for [Etherbets](https://github.com/izcoser/etherbets).

Current work in progress available at: https://etherbets.org/

# To do

- [x] Create Aggregator contract for Sports Bets - Done. Aggregate results using reports from [TheRundown](https://market.link/nodes/TheRundown/integrations) and [SportsDataIO](https://market.link/nodes/SportsDataIO/integrations). This contract accepts bets on home and away team, then fetches results from both providers and pays out whoever bet on the winning team.

- [x] Add events to all three betting apps. - Done. Now just have to update the frontend to listen to all events.

- [ ] Explore using multiple Chainlink Price Feeds as source of randomness (several price values multiplied by each other).

- [ ] Upgrade to Chainlink VRF v2.

- [ ] Unite bet instances into a single contract to decrease costs.

- [ ] Explore other oracle options.

- [ ] Use Chainlink Keepers to automate the flow of the systems.

- [ ] Get rid of public variables (used for debugging).

- [ ] Use Fisher–Yates shuffle to expand numbers from the random seed more efficiently.
