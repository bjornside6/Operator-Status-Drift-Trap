// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITrap} from "drosera-contracts/interfaces/ITrap.sol";

/// Minimal DelegationManager subset
interface IDelegationManager {
    function operatorStatus(address operator) external view returns (uint8);
}

/// OperatorConfig interface (persistent contract you deploy)
interface IOperatorConfig {
    function getOperators() external view returns (address[] memory);
    function getAllowedStatusMask() external view returns (uint256);
}

/// Stateless trap: collect() returns the current sample; shouldRespond compares newest vs previous.
/// Replace OPERATOR_CONFIG placeholder below with your deployed OperatorConfig address prior to compile.
contract OperatorStatusDriftTrap is ITrap {
    // Replace the OPERATOR_CONFIG address with your deployed OperatorConfig contract address.
    // e.g. address public constant OPERATOR_CONFIG = 0xYourDeployedConfigHere;
    address public constant OPERATOR_CONFIG = 0x1B622162B8fA1086247604231eAd3F1fEBD3ffCf;

    // Hoodi DelegationManager address from Layr-Labs deployments (hardcoded).
    // Source: Layr-Labs eigenlayer-contracts README (Hoodi DelegationManager).
    address public constant DELEGATION_MANAGER = 0x867837a9722C512e0862d8c2E15b8bE220E8b87d;

    /// collect: external view, cheap — reads operator list from persistent config, returns (ops[], currents[], ts)
    function collect() external view returns (bytes memory) {
        address[] memory ops = IOperatorConfig(OPERATOR_CONFIG).getOperators();
        uint256 n = ops.length;
        uint8[] memory currents = new uint8[](n);

        for (uint i = 0; i < n; i++) {
            // single external call per operator
            currents[i] = IDelegationManager(DELEGATION_MANAGER).operatorStatus(ops[i]);
        }

        return abi.encode(ops, currents, uint64(block.timestamp));
    }

    /// shouldRespond: pure & deterministic. Compare newest (data[0]) vs previous (data[1]).
    /// Uses allowedStatusMask read from config by collectors/relay if needed — but because shouldRespond
    /// must be pure, the allowedStatusMask is expected to have been encoded into the collect output
    /// if you want the mask to affect on-chain decision; here we implement a pattern where the relay
    /// includes the allowed mask in the encoded sample to keep shouldRespond pure and deterministic.
    ///
    /// To enable this, collectors (Drosera relay) should encode: (address[] ops, uint8[] cur, uint64 ts, uint256 allowedMask)
    ///
    /// For backward compatibility if data decode without mask, we treat mask == (1<<1) by default.
    function shouldRespond(bytes[] calldata data) external pure returns (bool, bytes memory) {
        if (data.length < 2) {
            return (false, bytes(""));
        }

        // decode newest; try the extended shape (ops, cur, ts, allowedMask) first
        // we need to attempt a decode that supports both shapes; to keep shouldRespond pure and simple,
        // we require the relay to include allowedMask in the collect encoding as the last item.
        // decode newest:
        (address[] memory opsN, uint8[] memory curN, uint64 tsN, uint256 allowedMaskN) = abi.decode(
            data[0],
            (address[], uint8[], uint64, uint256)
        );

        (address[] memory opsP, uint8[] memory curP, uint64 tsP, uint256 allowedMaskP) = abi.decode(
            data[1],
            (address[], uint8[], uint64, uint256)
        );

        // sanity: lengths and ordering must match
        if (opsN.length != opsP.length || opsN.length != curN.length || curP.length != curN.length) {
            return (false, bytes(""));
        }

        // use the newest mask (allowedMaskN) for checks
        uint256 mask = allowedMaskN;
        if (mask == 0) {
            // fallback default: allow status == 1 only
            mask = (1 << 1);
        }

        // iterate deterministically
        for (uint i = 0; i < opsN.length; i++) {
            if (opsN[i] != opsP[i]) {
                // if ordering differs, skip to be conservative
                continue;
            }

            uint8 prev = curP[i];
            uint8 cur = curN[i];

            if (cur != prev) {
                // test if cur is allowed (bit test)
                bool curAllowed = ((mask >> uint256(cur)) & 1) == 1;
                if (!curAllowed) {
                    bytes32 tag = bytes32("OP_STATUS_DRIFT");
                    return (true, abi.encode(opsN[i], prev, cur, tag));
                }
            }
        }

        return (false, bytes(""));
    }
}
