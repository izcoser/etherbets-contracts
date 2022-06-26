// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";

/**
 * **** Data Conversions ****
 *
 * leagueId (uint256)
 * --------------------------
 * Value    Type
 * --------------------------
 * 0        MLB
 *
 *
 * market (uint256)
 * --------------------------
 * Value    Type
 * --------------------------
 * 0        create
 * 1        resolve
 *
 */
/**
 * @title A consumer contract for Sportsdataio.
 * @author LinkPool.
 * @notice Interact with the GamesByDate API (sportsdataio-linkpool adapter).
 * @dev Uses @chainlink/contracts 0.4.0.
 */
contract SportsdataioLinkPoolConsumerOracle is ChainlinkClient {
    using Chainlink for Chainlink.Request;
    using CBORChainlink for BufferChainlink.buffer;

    struct GameCreateMlb {
        uint32 gameId;
        uint40 startTime;
        string homeTeam;
        string awayTeam;
    }
    struct GameResolveMlb {
        uint32 gameId;
        uint8 homeScore;
        uint8 awayScore;
        bytes20 status;
    }
    mapping(bytes32 => bytes32[]) public requestIdGames;

    error FailedTransferLINK(address to, uint256 amount);

    /**
     * @param _link the LINK token address.
     * @param _oracle the Operator.sol contract address.
     */
    constructor(address _link, address _oracle) {
        setChainlinkToken(_link);
        setChainlinkOracle(_oracle);
    }

    /* ========== EXTERNAL FUNCTIONS ========== */

    function cancelRequest(
        bytes32 _requestId,
        uint256 _payment,
        bytes4 _callbackFunctionId,
        uint256 _expiration
    ) external {
        cancelChainlinkRequest(_requestId, _payment, _callbackFunctionId, _expiration);
    }

    /**
     * @notice Stores the scheduled games.
     * @param _requestId the request ID for fulfillment.
     * @param _result the games either to be created or resolved.
     */
    function fulfillSchedule(bytes32 _requestId, bytes32[] memory _result)
        external
        recordChainlinkFulfillment(_requestId)
    {
        requestIdGames[_requestId] = _result;
    }

    /**
     * @notice Requests the tournament games either to be created or to be resolved on a specific date.
     * @dev Requests the 'schedule' endpoint. Result is an array of GameCreate or GameResolve encoded (see structs).
     * @param _specId the jobID.
     * @param _payment the LINK amount in Juels (i.e. 10^18 aka 1 LINK).
     * @param _market the number associated with the type of market (see Data Conversions).
     * @param _leagueId the tournament ID.
     * @param _date the starting time of the event as a UNIX timestamp in seconds.
     */
    function requestSchedule(
        bytes32 _specId,
        uint256 _payment,
        uint256 _market,
        uint256 _leagueId,
        uint256 _date
    ) external {
        Chainlink.Request memory req = buildChainlinkRequest(_specId, address(this), this.fulfillSchedule.selector);

        req.addUint("market", _market);
        req.addUint("leagueId", _leagueId);
        req.addUint("date", _date);

        sendChainlinkRequest(req, _payment);
    }

    /**
     * @notice Requests the tournament games either to be created or to be resolved on a specific date.
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
        uint256[] calldata _gameIds
    ) external {
        Chainlink.Request memory req = buildChainlinkRequest(_specId, address(this), this.fulfillSchedule.selector);

        req.addUint("market", _market);
        req.addUint("leagueId", _leagueId);
        req.addUint("date", _date);
        _addUintArray(req, "gameIds", _gameIds);

        sendChainlinkRequest(req, _payment);
    }

    function setOracle(address _oracle) external {
        setChainlinkOracle(_oracle);
    }

    function withdrawLink(uint256 _amount, address payable _payee) external {
        LinkTokenInterface linkToken = LinkTokenInterface(chainlinkTokenAddress());
        _requireTransferLINK(linkToken.transfer(_payee, _amount), _payee, _amount);
    }

    /* ========== EXTERNAL VIEW FUNCTIONS ========== */

    function getGameCreateMlb(bytes32 _requestId, uint256 _idx) external view returns (GameCreateMlb memory) {
        return _getGameCreateMlbStruct(requestIdGames[_requestId][_idx]);
    }

    function getGameResolveMlb(bytes32 _requestId, uint256 _idx) external view returns (GameResolveMlb memory) {
        return _getGameResolveMlbStruct(requestIdGames[_requestId][_idx]);
    }

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

    function _getGameCreateMlbStruct(bytes32 _data) private pure returns (GameCreateMlb memory) {
        GameCreateMlb memory gameCreateMlb = GameCreateMlb(
            uint32(bytes4(_data)),
            uint40(bytes5(_data << 32)),
            string(abi.encodePacked(bytes10(_data << 72))),
            string(abi.encodePacked(bytes10(_data << 152)))
        );
        return gameCreateMlb;
    }

    function _getGameResolveMlbStruct(bytes32 _data) private pure returns (GameResolveMlb memory) {
        GameResolveMlb memory gameResolveMlb = GameResolveMlb(
            uint32(bytes4(_data)),
            uint8(bytes1(_data << 32)),
            uint8(bytes1(_data << 40)),
            bytes20(_data << 48)
        );
        return gameResolveMlb;
    }

    function _requireTransferLINK(
        bool _success,
        address _to,
        uint256 _amount
    ) private pure {
        if (!_success) {
            revert FailedTransferLINK(_to, _amount);
        }
    }
}