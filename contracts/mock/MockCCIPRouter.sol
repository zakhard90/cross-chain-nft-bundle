// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Client } from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import { IRouterClient } from "@chainlink/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import { CCIPReceiver } from "@chainlink/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol";

contract MockCCIPRouter is IRouterClient {
  function ccipSend(uint64, Client.EVM2AnyMessage memory message) external payable returns (bytes32 messageId) {
    return keccak256(abi.encode(message));
  }

  function getFee(uint64, Client.EVM2AnyMessage memory) external pure returns (uint256 fee) {
    return 0.001 ether;
  }

  function getSupportedTokens(uint64) external pure returns (address[] memory tokens) {
    tokens = new address[](0);
    return tokens;
  }

  function isChainSupported(uint64) external pure returns (bool supported) {
    return true;
  }

  function getRouter() external view returns (address) {
    return address(this);
  }

  function simulateSend(Client.Any2EVMMessage memory _message, address _receiver) public {
    CCIPReceiver receiver = CCIPReceiver(_receiver);
    receiver.ccipReceive(_message);
  }
}
