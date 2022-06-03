
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
 
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
// THIS IS FOR RINKEBY.

interface EtherBets {
    function setRandomNumber(uint256 _randomNumber) external;
}

contract RandomNumberConsumer is VRFConsumerBase{
     
    bytes32 internal keyHash;
    uint256 internal fee;
 
    uint256 public randomResult;
    mapping(bytes32 => address) public requestIdToAddress;

    constructor() 
        VRFConsumerBase(
            0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B, // VRF Coordinator on Rinkeby
            0x01BE23585060835E02B77ef475b0Cc51aA1e0709  // LINK Token on Rinkeby
        )
    {
            keyHash = 0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311;
            fee = 0.1 * 10 ** 18; // 0.1 LINK on Rinkeby
    }

    event RandomnessRequested(address indexed sender);
    event RandomnessFulfilled(address indexed sender, bytes32 requestId, uint256 randomness);

    /** 
    * Requests randomness 
    */
    function getRandomNumber() public returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        requestId = requestRandomness(keyHash, fee);
        emit RandomnessRequested(msg.sender);
        requestIdToAddress[requestId] = msg.sender;
    }

    /**
    * Callback function used by VRF Coordinator
    */
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        address requestAddress = requestIdToAddress[requestId];
        EtherBets e = EtherBets(requestAddress);
        e.setRandomNumber(randomness);
        emit RandomnessFulfilled(requestAddress, requestId, randomness);
    }

    function withdrawLink() external {
        LINK.transfer(msg.sender, LINK.balanceOf(address(this)));
    }
}
