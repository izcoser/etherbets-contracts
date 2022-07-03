// SPDX-License-Identifier: MIT
// Contract for bets on the Major League Baseball.
// Results are aggregated from 2 ChainLINK Data Providers: TheRundown and SportsDataIO.
// Users can bet on the home team or the away team.
// Assumes no draws are possible.
// Bets can be made until the game starts, and prizes are paid out 10 hours from the start of the game. Longest ever game was 8h long.

pragma solidity ^0.8.9;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";

contract EtherBaseballBets is ChainlinkClient {
    using Chainlink for Chainlink.Request;
    using CBORChainlink for BufferChainlink.buffer;

    struct GameResolveSD {
        uint32 gameId;
        uint8 homeScore;
        uint8 awayScore;
        bytes20 status;
    }
    struct GameResolveRD {
        bytes32 gameId;
        uint8 homeScore;
        uint8 awayScore;
        uint8 statusId;
    }

    struct Bet{
        uint home;
        uint away;
    }

    struct ContractDetails{
        Bet total;
        Bet userBet;
        uint claimablePrize;
        bool fetchedSD;
        bool fetchedRD;
        string homeTeam;
        string awayTeam;
        uint8 homeScore;
        uint8 awayScore;
        uint gameDate;
        uint32 gameIdSD;
        bytes32 gameIDRD;
        bool resultsAggregated;
        bool resultConsensus;
        bool homeWinner;
    }

    Bet public total;
    
    GameResolveSD public resultSD;
    GameResolveRD public resultRD;

    bool public fetchedSD;
    bool public fetchedRD;

    string public homeTeam;
    string public awayTeam;

    uint256 public gameDate;
    uint32 public gameIdSD;
    bytes32 public gameIdRD;

    bool public resultsAggregated;
    bool public resultConsensus;
    bool public homeWinner;

    uint constant decimals = 10 ** 12;

    mapping(address => Bet) addressToBet;

    function getDetails(address user) public view returns (ContractDetails memory c){
        c.total = total;
        c.userBet = addressToBet[user];
        c.claimablePrize = claimablePrize(user);
        c.fetchedSD = fetchedSD;
        c.fetchedRD = fetchedRD;
        c.homeTeam = homeTeam;
        c.awayTeam = awayTeam;
        c.homeScore = resultSD.homeScore;
        c.awayScore = resultSD.awayScore;
        c.gameDate = gameDate;
        c.gameIdSD = gameIdSD;
        c.gameIDRD = gameIdRD;
        c.resultsAggregated = resultsAggregated;
        c.resultConsensus = resultConsensus;
        c.homeWinner = homeWinner;
    }

    /**
     * @param _link the LINK token address.
     * @param _oracle the Operator.sol contract address.
     */
     constructor(address _link, address _oracle, uint256 _date, uint32 _gameIdSD, bytes32 _gameIdRD, string memory _homeTeam, string memory _awayTeam) {
        setChainlinkToken(_link);
        setChainlinkOracle(_oracle);
        gameDate = _date;
        gameIdSD = _gameIdSD;
        gameIdRD = _gameIdRD;
        homeTeam = _homeTeam;
        awayTeam = _awayTeam;
    }

    /* Begin SportsDataIO specific methods. */

    /**
     * @notice Stores the scheduled games (SD).
     * @param _requestId the request ID for fulfillment.
     * @param _result the games either to be created or resolved.
    */
    function fulfillSchedule(bytes32 _requestId, bytes32[] memory _result)
        external
        recordChainlinkFulfillment(_requestId)
    {
        bytes32 data = _result[0];
        resultSD = GameResolveSD(
            uint32(bytes4(data)),
            uint8(bytes1(data << 32)),
            uint8(bytes1(data << 40)),
            bytes20(data << 48)
        );
        fetchedSD = true;
    }

    /**
     * @notice Requests the tournament games either to be created or to be resolved on a specific date (SD).
     * @dev Requests the 'schedule' endpoint. Result is an array of GameCreate or GameResolve encoded (see structs).
     * @param _specId the jobID.
     * @param _payment the LINK amount in Juels (i.e. 10^18 aka 1 LINK).
     * @param _market the context of the games data to be requested: `0` (markets to be created),
     * `1` (markets to be resolved).
     * @param _leagueId the tournament ID.
     * @param _date the date to request events by, as a UNIX timestamp in seconds.
     * @param _gameIds the list of game IDs to filter by for market `1`, otherwise the value is ignored.
     */
     function requestSchedule(
        bytes32 _specId,
        uint256 _payment,
        uint256 _market,
        uint256 _leagueId,
        uint256 _date,
        uint256[] memory _gameIds
    ) internal {
        Chainlink.Request memory req = buildChainlinkRequest(_specId, address(this), this.fulfillSchedule.selector);

        req.addUint("market", _market);
        req.addUint("leagueId", _leagueId);
        req.addUint("date", _date);
        _addUintArray(req, "gameIds", _gameIds);

        sendChainlinkRequest(req, _payment);
    }


    function _addUintArray(
        Chainlink.Request memory _req,
        string memory _key,
        uint256[] memory _values
    ) private pure {
        Chainlink.Request memory r2 = _req;
        r2.buf.encodeString(_key);
        r2.buf.startArray();
        uint256 valuesLength = _values.length;
        for (uint256 i = 0; i < valuesLength; ) {
            r2.buf.encodeUInt(_values[i]);
            unchecked {
                ++i;
            }
        }
        r2.buf.endSequence();
        _req = r2;
    }

    /* End SportsDataIO specific methods. */

    /* Begin TheRunDown specific methods. */

    function fulfillGames(bytes32 _requestId, bytes[] memory _games) public recordChainlinkFulfillment(_requestId) {
        resultRD = abi.decode(_games[0], (GameResolveRD));
        fetchedRD = true;
    }

    /**
     * @notice Returns games for a given date (RD).
     * @dev Result format is array of encoded tuples.
     * @param _specId the jobID.
     * @param _payment the LINK amount in Juels (i.e. 10^18 aka 1 LINK).
     * @param _market the type of games we want to query (create or resolve).
     * @param _sportId the sportId of the sport to query.
     * @param _date the date for the games to be queried (format in epoch).
     * @param _gameIds the IDs of the games to query (array of gameId).
     * @param _statusIds the IDs of the statuses to query (array of statusId).
     */

    function requestGamesResolveWithFilters(
        bytes32 _specId,
        uint256 _payment,
        string memory _market,
        uint256 _sportId,
        uint256 _date,
        string[] memory _statusIds,
        string[] memory _gameIds
    ) public {
        Chainlink.Request memory req = buildChainlinkRequest(_specId, address(this), this.fulfillGames.selector);

        req.addUint("date", _date);
        req.add("market", _market);
        req.addUint("sportId", _sportId);
        req.addStringArray("statusIds", _statusIds);
        req.addStringArray("gameIds", _gameIds);
        sendChainlinkRequest(req, _payment);
    }

    /* End TheRunDown specific methods. */

    function requestResultFromSD() public{
        require(fetchedSD == false, "SD result has already been fetched.");
        require(block.timestamp > gameDate + 3600 * 10, "Wait until 10h after the game to fetch results.");
        uint[] memory _gameIds = new uint[](1);
        _gameIds[0] = gameIdSD;
        requestSchedule('bade3601c5ff496586d636c3995f06fe', 100000000000000000, 1, 0, gameDate, _gameIds);
    }

    function requestResultFromRD() public {
        require(fetchedRD == false, "RD result has already been fetched.");
        require(block.timestamp > gameDate + 3600 * 10, "Wait until 10h after the game to fetch results.");
        string[] memory _statusIds;
        string[] memory _gameIds = new string[](1);
        _gameIds[0] = string(abi.encodePacked(gameIdRD));
        requestGamesResolveWithFilters('9de17351dfa5439d83f5c2f3707ffa9e', 100000000000000000, "resolve", 3, gameDate, _statusIds, _gameIds);
    }

    function setOracle(address _oracle) external {
        setChainlinkOracle(_oracle);
    }

    function withdrawLink() public {
        LinkTokenInterface linkToken = LinkTokenInterface(chainlinkTokenAddress());
        require(linkToken.transfer(msg.sender, linkToken.balanceOf(address(this))), "Unable to transfer");
    }

    /* Betting methods */

    // Place bet with home == true if you think homeTeam will win.
    function placeBet(bool home) public payable{
        require(msg.value > 0, "msg.value has to be more than 0");
        require(block.timestamp < gameDate, "You can't place bets anymore, game has started.");
        if (home){
            addressToBet[msg.sender].home += msg.value;
            total.home += msg.value;
        }
        else{
            addressToBet[msg.sender].away += msg.value;
            total.away += msg.value;
        }
    }

    function aggregateResults() public{
        require(!resultsAggregated, "Results have already been aggregated.");
        require(fetchedRD && fetchedSD, "Results have to be fetched from both oracles before aggregation.");
        resultsAggregated = true;
        resultConsensus = (resultSD.homeScore == resultRD.homeScore) && (resultSD.awayScore == resultRD.awayScore);
        homeWinner = resultSD.homeScore > resultSD.awayScore;
    }

    function claimablePrize(address user) public view returns (uint){
        if(!resultsAggregated || !resultConsensus){
           return 0;
        }

        uint prizeShare;
        
        if (homeWinner){
            if(total.home > 0){ // handle division by zero.
                prizeShare = (addressToBet[user].home * decimals) / total.home;
            }
            else{
                prizeShare = 0;
            }
            
        }
        else{
            if(total.away > 0){
                prizeShare = (addressToBet[user].away * decimals) / total.away;
            }
            else{
                prizeShare = 0;
            }
        }

        uint prize = (prizeShare * (total.home + total.away)) / decimals;
        return prize;
    }

    function claimPrize() public{
        require(resultsAggregated, "Results have not been aggregated yet.");
        require(resultConsensus, "Results have no consensus.");

        uint prize = claimablePrize(msg.sender);
        require(prize > 0, "You did not win any prize.");

        (bool sent,) = payable(msg.sender).call{value: prize}("");
        require(sent, "Failed to send Ether.");
    }

}