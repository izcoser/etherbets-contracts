// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

// EtherBetsv2. Here I'm going to implement the following changes:
// Chainlink VRF V2: makes it so much easier to obtain random numbers and has more custom options.
// Use the Fisher-Yates shuffling algorithm to expand the random seed into n random numbers - more gas efficient.
// Let each user claim the prize by himself.

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";


/*contract EtherBetsV2Factory{
    event NewLottery(address lottery);
    address[] public contracts;

    function newEtherBetsV2(string memory _name, uint _betCost, uint8 _maximumNumber, uint8 _picks, uint256 _timeBetweenDraws, uint64 _subscriptionId) public returns (address){
        EtherBetsV2 e = new EtherBetsV2(_name,_betCost, _maximumNumber, _picks, _timeBetweenDraws, _subscriptionId);
        contracts.push(address(e));
        emit NewLottery(address(e));
        return address(e);
    }
}*/

contract EtherBetsV2 is VRFConsumerBaseV2{
    event NumbersDrawn(uint8[] winningNumbers, uint256 draw);
    event BetPlaced(address indexed sender, uint bet, uint256 draw);
    event RandomnessRequested(uint256 draw);
    event RandomnessFulfilled(uint256 randomness, uint256 draw);

    VRFCoordinatorV2Interface COORDINATOR;

    // Your subscription ID.
    uint64 s_subscriptionId;
  
    // Goerli coordinator. For other networks,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    address vrfCoordinator;// = 0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D;
  
    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    bytes32 keyHash;// = 0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15;
  
    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 callbackGasLimit = 500000;
  
    // The default is 3, but you can set this higher.
    uint16 requestConfirmations = 3;
  
    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint32 numWords =  1;

    uint256 s_requestId;
    address s_owner;

    /**
     * The name of this lottery instance.
     */
    string name;
    
    /**
     * The cost in {native token} to place a bet.
     */
    uint256 betCost;
    
    /**
     * The largest number that can be picked/drawn (up to 255).
     */
    uint8 maximumNumber;

    /**
     * How many numbers must be picked in a bet. 
     */
    uint8 picks;

    uint8[] winningNumbers;
    
    /**
     * A number representing the draw, it is incremented after each draw.
     */
    uint256 draw;

    /**
     * Maps an address to a draw, which maps to bets.
     * Is used to map an address to all of its bets on a specific draw.
     * Access like this: addressToBets[i][j] to get all of i's bets on the j-th draw,
     * or addressToBets[i][j][k] to get the k-th bet.
     * Note: A bet is a uint256 represented by arrayToUint([bet_numbers]).
    */
    mapping(address => mapping(uint => uint[])) addressToBets;

    /**
     * Maps a bet to a draw, which maps to a counter.
     * Is used to keep track of how many bets were made
     * with the same number, to share the pool
     * when claiming prizes.
     * Access like this: betCounter[i][j] to get the number of bets i made on the j-th draw.
    */
    mapping(uint => mapping(uint => uint)) betCounter;

    /**
     * Maps a draw to its accumulated prize.
    */
    mapping(uint => uint) drawToPrize;

    /**
     * Maps an address to a draw, which maps to whether or not
     * the prize has been claimed.
     * Is used to prevent reentrancy attacks.
    */
    mapping(address => mapping(uint => bool)) addressToClaim;

    /**
     * Stores the time in seconds of the last draw.
     */
    uint256 lastDrawTime;

    /**
     * Stores the minimum wait time in seconds between draws.
     */
    uint256 timeBetweenDraws;

    bool paused;

    uint256 randomNumber;

    uint constant decimals = 10 ** 18;

    uint constant fee = 10; // 1% fee on bets to pay for VRF.

    uint constant accumulation = 500; // 50% always accumulates to the next round.

    uint public treasury;

    address public upkeeper;

    struct ContractDetails{
        string name;
        uint betCost;
        uint maximumNumber;
        uint8 picks;
        uint timeBetweenDraws;
        uint lastDrawTime;
        bool paused;
        uint draw;
        uint prize;
        uint8[] winningNumbers;
        uint randomNumber;
    }

    constructor(string memory _name, uint _betCost, uint8 _maximumNumber, uint8 _picks, uint256 _timeBetweenDraws,
        uint64 _subscriptionId, address _vrfCoordinator, bytes32 _keyHash) VRFConsumerBaseV2(_vrfCoordinator){
        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
        s_owner = msg.sender;
        s_subscriptionId = _subscriptionId;
        keyHash = _keyHash;
        name = _name;
        betCost = _betCost;
        maximumNumber = _maximumNumber;
        picks = _picks;
        timeBetweenDraws = _timeBetweenDraws;
        lastDrawTime = block.timestamp;
    }

    function setUpkeeper(address _upkeeper) external onlyOwner{
        upkeeper = _upkeeper;
    }

    function getDetails() external view returns (ContractDetails memory c){
        c.name = name;
        c.betCost = betCost;
        c.maximumNumber = maximumNumber;
        c.picks = picks;
        c.timeBetweenDraws = timeBetweenDraws;
        c.lastDrawTime = lastDrawTime;
        c.paused = paused;
        c.draw = draw;
        c.prize = drawToPrize[draw];
        c.winningNumbers = winningNumbers;
        c.randomNumber = randomNumber;
    }

    /**
     * Expands the random seed into n unique pseudorandom
     * numbers from 1 to m, using the Ficher Yates schuffle.
     * Conditions: m > n.
     */
    function expand(uint256 seed, uint8 n, uint8 m) public pure returns (uint8[] memory){
        uint8[] memory arr = new uint8[](m);
        for(uint8 i = 0; i < m; i++){
            arr[i] = i + 1;
        }

        uint8 last = m - 1;
        uint8[] memory nums = new uint8[](n);
        for(uint i = 0; i < n; i++){
            uint8 roll = uint8(uint256(keccak256(abi.encode(seed, i))) % (m - i));
            nums[i] = arr[roll];
            arr[roll] = arr[last];
            last--; // will break (underflow) if m == n
        }
        return nums;
    }

    /**
     * Receives a uint8 array, returns a uint256 unique to the number of that array.
     * Example: arr = [1, 2, 3] -> number = 0b000...111
     *          arr = [255, 1, 2] -> number = 0b100...011
     * Input numbers must be between 1 and 255.
     */
    function arrayToUint(uint8[] memory arr) internal pure returns (uint){
        uint number = 0;
        for(uint8 i = 0; i < arr.length; i++){
            number |= (1 << (arr[i] - 1));
        }
        return number;
    }

    function beginDraw() external onlyOwner{
        require(block.timestamp - lastDrawTime > timeBetweenDraws, "You must wait longer before another draw is available.");
        require(paused == false, "A draw is already happening");
        paused = true; // pause bets to wait for the result.
        requestRandomWords();
        emit RandomnessRequested(draw);
    }

    function placeBet(uint bet) external payable{
        require(msg.value == betCost, "msg.value does not match betCost");
        require(paused == false, "Bets are paused to draw the numbers.");
        addressToBets[msg.sender][draw].push(bet);
        betCounter[bet][draw]++;
        drawToPrize[draw] += (betCost * (1000 - fee - accumulation)) / 1000;
        drawToPrize[draw + 1] += (betCost * accumulation) / 1000;
        treasury += (betCost * fee) / 1000;
        emit BetPlaced(msg.sender, bet, draw);
    }

    function claimPrize(uint256 _draw) external{
        require(draw > _draw, "Specified draw hasn't occurred yet.");
        require(addressToClaim[msg.sender][_draw] == false, "Address has already claimed a prize.");

        addressToClaim[msg.sender][_draw] == true;
        uint prize = claimablePrize(msg.sender, _draw);
        require(prize > 0, "You did not win any prize.");

        (bool sent,) = payable(msg.sender).call{value: prize}("");
        require(sent, "Failed to send Ether.");
    }

    function claimablePrize(address user, uint256 _draw) public view returns (uint){
        if(draw <= _draw || addressToClaim[user][_draw]){
           return 0;
        }

        uint winningBet = arrayToUint(winningNumbers);
        uint totalWinningTickets = betCounter[winningBet][_draw];
        if(totalWinningTickets == 0){
            return 0;
        }

        uint userBetCount = addressToBets[user][_draw].length;
        uint wins = 0;

        for(uint i = 0; i < userBetCount; i++){
            if(addressToBets[user][_draw][i] == winningBet){
                wins++;
            }
        }
        
        uint prizeShare = (wins * decimals) / totalWinningTickets;
        return (prizeShare * drawToPrize[_draw]) / decimals;
    }

      // Assumes the subscription is funded sufficiently.
    function requestRandomWords() internal {
        // Will revert if subscription is not set and funded.
        s_requestId = COORDINATOR.requestRandomWords(
        keyHash,
        s_subscriptionId,
        requestConfirmations,
        callbackGasLimit,
        numWords
        );
    }

    function fulfillRandomWords(
        uint256, /* requestId */
        uint256[] memory randomWords
    ) internal override {
        randomNumber = randomWords[0];
        winningNumbers = expand(randomWords[0], picks, maximumNumber);
        emit NumbersDrawn(winningNumbers, draw);
        lastDrawTime = block.timestamp;
        
        if (betCounter[arrayToUint(winningNumbers)][draw] == 0){
            drawToPrize[draw + 1] += drawToPrize[draw];
        }

        draw++;
        paused = false;
    }

    function withdrawTreasury() external onlyOwner{
        uint amount = treasury;
        treasury = 0;
        (bool sent,) = payable(msg.sender).call{value: amount}("");
        require(sent);
    }

    function addToPool() external payable{
        drawToPrize[draw] += msg.value;
    }

    modifier onlyOwner() {
        require(msg.sender == s_owner);
        _;
    }

    modifier onlyUpkeeper(){
        require(msg.sender == upkeeper);
        _;
    }
}
