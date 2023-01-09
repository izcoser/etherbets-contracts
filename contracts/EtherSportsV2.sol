// SPDX-License-Identifier: MIT
// Contract for sport bets using only TheRundown as a data source.
// Intended to be deployed to Optimism and Polygon - both networks covered by TheRundown.
// Users can bet on the home team, away team or draw.
// As opposed to EtherSports.sol, all bets are in a single contract - no deploying new contracts.
// Bets can be made until the game starts, and prizes are paid out 10 hours from the start of the game. Longest ever game was 8h long.

pragma solidity 0.8.15;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";

contract EtherSportsV2 is ChainlinkClient {
    using Chainlink for Chainlink.Request;
    using CBORChainlink for BufferChainlink.buffer;

    error FailedTransferLINK(address to, uint256 amount);
    error GameStarted(bytes32 gameId);
    error GameNotFinished(bytes32 gameId);
    error NoPrizeToClaim(bytes32 gameId);
    error FailedClaimPrize(bytes32 gameId, uint prize, uint balance);
    error ZeroValueBet();

    event ResultFetched(uint8 homeScore, uint8 awayScore, Choice result, bytes32 gameId);
    event BetPlaced(address indexed sender, uint amount, Choice choice, bytes32 gameId);

    enum Status { OPEN, CLOSED, WAIT_RESULT, FINISHED }
    enum Choice { HOME, AWAY, DRAW }

    // Result of the game as provided by oracle.
    struct GameResolve{
        bytes32 gameId;
        uint8 homeScore;
        uint8 awayScore;
        uint8 statusId;
    }

    struct GameInfo{
        Status status;
        Choice result;
        uint[3] total; // total bet on each choice.
        string homeTeam;
        uint8 homeScore;
        string awayTeam;
        uint8 awayScore;
        uint date;
        bytes32 id;
    }

    /*struct ContractDetails{
        Bet total;
        Bet userBet;
        uint claimablePrize;
        bool fetched;
        string homeTeam;
        string awayTeam;
        uint8 homeScore;
        uint8 awayScore;
        uint gameDate;
        bytes32 gameID;
        bool homeWinner;
    }*/

    uint constant decimals = 10 ** 12;
    mapping(bytes32 => GameInfo) idToGame;
    mapping(address => mapping(bytes32 => uint[3])) addressGameBet;
/*
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
    }*/

    /**
     * @param _link the LINK token address.
     * @param _oracle the Operator.sol contract address.
     */
     constructor(address _link, address _oracle) {
        setChainlinkToken(_link);
        setChainlinkOracle(_oracle);
    }

    /* Begin TheRunDown specific methods. */

    function cancelRequest(
        bytes32 _requestId,
        uint256 _payment,
        bytes4 _callbackFunctionId,
        uint256 _expiration
    ) external {
        cancelChainlinkRequest(_requestId, _payment, _callbackFunctionId, _expiration);
    }
/*
    function fulfillGames(bytes32 _requestId, bytes[] memory _games) external recordChainlinkFulfillment(_requestId) {
        requestIdGames[_requestId] = _games;
    }*/

    /*
     * @notice Returns an array of game data for a given market, sport ID, and date.
     * @dev Result format is array of either encoded GameCreate tuples or encoded GameResolve tuples.
     * @param _specId the jobID.
     * @param _payment the LINK amount in Juels (i.e. 10^18 aka 1 LINK).
     * @param _market the type of game data to be queried ("create" or "resolve").
     * @param _sportId the ID of the sport to be queried (see supported sportId).
     * @param _date the date for the games to be queried (format in epoch).
     *//*
    function requestGames(
        bytes32 _specId,
        uint256 _payment,
        string calldata _market,
        uint256 _sportId,
        uint256 _date
    ) external {
        Chainlink.Request memory req = buildOperatorRequest(_specId, this.fulfillGames.selector);

        req.addUint("date", _date);
        req.add("market", _market);
        req.addUint("sportId", _sportId);

        sendOperatorRequest(req, _payment);
    }*/

    /*
     * @notice Returns an Array of game data for a given market, sport ID, date and other filters.
     * @dev Result format is array of either encoded GameCreate tuples or encoded GameResolve tuples.
     * @dev "gameIds" is optional.
     * @dev "statusIds" is optional, and ignored for market "create".
     * @param _specId the jobID.
     * @param _payment the LINK amount in Juels (i.e. 10^18 aka 1 LINK).
     * @param _market the type of game data to be queried ("create" or "resolve").
     * @param _sportId the ID of the sport to be queried (see supported sportId).
     * @param _date the date for the games to be queried (format in epoch).
     * @param _gameIds the IDs of the games to be queried (array of game ID as its string representation, e.g.
     * ["23660869053591173981da79133fe4c2", "fb78cede8c9aa942b2569b048e649a3f"]).
     * @param _statusIds the IDs of the statuses to be queried (an array of statusId, e.g. ["1","2","3"],
     * see supported statusIds).
     */

     /*
    function requestGamesFiltering(
        bytes32 _specId,
        uint256 _payment,
        string calldata _market,
        uint256 _sportId,
        uint256 _date,
        bytes32[] memory _gameIds,
        uint256[] memory _statusIds
    ) external {
        Chainlink.Request memory req = buildOperatorRequest(_specId, this.fulfillGames.selector);

        req.add("market", _market);
        req.addUint("sportId", _sportId);
        req.addUint("date", _date);
        req.addStringArray("gameIds", _bytes32ArrayToString(_gameIds)); // NB: optional filter
        _addUintArray(req, "statusIds", _statusIds); // NB: optional filter, ignored for market "create".

        sendOperatorRequest(req, _payment);
    }*/

    function setOracle(address _oracle) external {
        setChainlinkOracle(_oracle);
    }

    function withdrawLink(address payable _payee, uint256 _amount) external {
        LinkTokenInterface linkToken = LinkTokenInterface(chainlinkTokenAddress());
        if (!linkToken.transfer(_payee, _amount)) {
            revert FailedTransferLINK(_payee, _amount);
        }
    }

    /* ========== EXTERNAL VIEW FUNCTIONS ========== */
/*
    function getGamesCreated(bytes32 _requestId, uint256 _idx) external view returns (GameCreate memory) {
        GameCreate memory game = abi.decode(requestIdGames[_requestId][_idx], (GameCreate));
        return game;
    }*/
/*
    function getGamesResolved(bytes32 _requestId, uint256 _idx) external view returns (GameResolve memory) {
        GameResolve memory game = abi.decode(requestIdGames[_requestId][_idx], (GameResolve));
        return game;
    }*/

    function getOracleAddress() external view returns (address) {
        return chainlinkOracleAddress();
    }

    /* ========== PRIVATE PURE FUNCTIONS ========== */

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

    function _bytes32ArrayToString(bytes32[] memory _bytes32Array) private pure returns (string[] memory) {
        string[] memory gameIds = new string[](_bytes32Array.length);
        for (uint256 i = 0; i < _bytes32Array.length; i++) {
            gameIds[i] = _bytes32ToString(_bytes32Array[i]);
        }
        return gameIds;
    }

    function _bytes32ToString(bytes32 _bytes32) private pure returns (string memory) {
        bytes memory bytesArray = new bytes(32);
        for (uint256 i; i < 32; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return string(bytesArray);
    }

    /* Betting methods */
    function placeBet(Choice choice, bytes32 gameId) external payable{
        if(msg.value == 0){
            revert ZeroValueBet();
        }

        if(block.timestamp > idToGame[gameId].date){
            revert GameStarted(gameId);
        }

        addressGameBet[msg.sender][gameId][uint(choice)] += msg.value;
        idToGame[gameId].total[uint(choice)] += msg.value;

        emit BetPlaced(msg.sender, msg.value, choice, gameId);
    }

    function claimablePrize(address user, bytes32 gameId) public view returns (uint){
        GameInfo memory game = idToGame[gameId];
        
        if(game.status != Status.FINISHED){
           return 0;
        }

        uint totalWinningBets = game.total[uint(game.result)];
        uint totalUserBet = addressGameBet[user][gameId][uint(game.result)];

        uint prizeShare = 0;

        if(totalWinningBets > 0){
            prizeShare = (totalUserBet * decimals) / totalWinningBets;
        }

        uint totalAllBets = game.total[uint(Choice.HOME)] + game.total[uint(Choice.AWAY)] + game.total[uint(Choice.DRAW)];
        uint prize = (prizeShare * (totalAllBets)) / decimals;
        return prize;
    }

    function claimPrize(bytes32 gameId) external {
        GameInfo memory game = idToGame[gameId];
        
        if(game.status != Status.FINISHED){
            revert GameNotFinished(game.id);
        }

        uint prize = claimablePrize(msg.sender, gameId);
        
        if(prize == 0){
            revert NoPrizeToClaim(game.id);
        }

        (bool sent,) = payable(msg.sender).call{value: prize}("");
        if(!sent){
            revert FailedClaimPrize(game.id, prize, address(this).balance);
        }
    }

    // For testing purposes. =========================DELETE IN PROD.==================
    function forceResult(bytes32 gameId, uint8 homeScore, uint8 awayScore, Choice result) external {
        GameInfo storage game = idToGame[gameId];
        game.homeScore = homeScore;
        game.awayScore = awayScore;
        game.result = result;
        game.status = Status.FINISHED;
    }
}