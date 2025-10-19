// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract OperatorResponder {
    address public owner;
    mapping(address => bool) public authorized;
    event OperatorAlert(address indexed operator, uint8 oldStatus, uint8 newStatus, bytes32 tag);
    event Authorize(address who, bool allowed);

    modifier onlyAuthorized() {
        require(authorized[msg.sender] || msg.sender == owner, "not authorized");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /// Called by the Drosera relay (or test harness) when the trap signals a response.
    /// This function mirrors the trap's encoded response payload.
    function respondWithOperatorAlert(address operator, uint8 oldStatus, uint8 newStatus, bytes32 tag) external onlyAuthorized {
        emit OperatorAlert(operator, oldStatus, newStatus, tag);
    }

    function authorize(address who, bool allowed) external onlyOwner {
        authorized[who] = allowed;
        emit Authorize(who, allowed);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }
}
