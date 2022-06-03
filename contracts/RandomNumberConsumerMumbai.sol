
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
 
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
// THIS IS FOR MUMBAI.

interface EtherBets {
    function setRandomNumber(uint256 _randomNumber) external;
}

contract RandomNumberConsumerMumbai is VRFConsumerBase{
     
    bytes32 internal keyHash;
    uint256 internal fee;
 
    uint256 public randomResult;
    mapping(bytes32 => address) public requestIdToAddress;

    constructor() 
        VRFConsumerBase(
            0x8C7382F9D8f56b33781fE506E897a4F1e2d17255, // VRF Coordinator on Mumbai
            0x326C977E6efc84E512bB9C30f76E30c160eD06FB  // LINK Token on Mumbai
        )
    {
            keyHash = 0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4;
            fee = 0.0001 * 10 ** 18; // 0.0001 LINK on Mumbai
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
