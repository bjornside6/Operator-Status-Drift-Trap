// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract OperatorResponder {
    address public owner;
    event OperatorAlert(address indexed operator, uint8 oldStatus, uint8 newStatus, bytes32 tag);

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /// Called by the Drosera relay (or test harness) when the trap signals a response.
    /// This function intentionally mirrors the trap's encoded response payload.
    function respondWithOperatorAlert(address operator, uint8 oldStatus, uint8 newStatus, bytes32 tag) external onlyOwner {
        emit OperatorAlert(operator, oldStatus, newStatus, tag);
    }

    /// Owner can transfer ownership (optional)
    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }
}
