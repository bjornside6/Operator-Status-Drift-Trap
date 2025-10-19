// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract OperatorConfig {
    address public owner;
    address[] private operators;
    uint256 private allowedStatusMask; // bitmask: bit k means status k allowed (0-indexed)

    event OperatorsUpdated(address[] ops);
    event AllowedStatusMaskUpdated(uint256 mask);
    event OwnershipTransferred(address oldOwner, address newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        // default: treat status 1 as healthy => set bit 1
        allowedStatusMask = (1 << 1);
    }

    /// Replace the entire operator list. Keep list bounded/small for gas reasons.
    function setOperators(address[] calldata ops) external onlyOwner {
        delete operators;
        for (uint i = 0; i < ops.length; i++) {
            operators.push(ops[i]);
        }
        emit OperatorsUpdated(ops);
    }

    /// Set the allowed status mask. Example: to allow statuses 0 and 1 => mask = (1<<0) | (1<<1) = 0b11 = 3
    function setAllowedStatusMask(uint256 mask) external onlyOwner {
        allowedStatusMask = mask;
        emit AllowedStatusMaskUpdated(mask);
    }

    function getOperators() external view returns (address[] memory) {
        return operators;
    }

    function getAllowedStatusMask() external view returns (uint256) {
        return allowedStatusMask;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }
}
