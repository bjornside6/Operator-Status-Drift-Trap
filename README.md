# Operator-Status-Drift-Trap
# OperatorStatusDriftTrap — EigenLayer Operator Status Drift Detector (PoC)

## Overview
**OperatorStatusDriftTrap** is a [Drosera](https://drosera.network)–compatible trap deployed on the Hoodi testnet.  
It monitors EigenLayer operator **status changes** via the `DelegationManager` contract and emits an alert whenever an operator’s status drifts from its previously snapshotted value.

The trap is designed as a PoC to demonstrate how Drosera traps can integrate with EigenLayer primitives to surface slashing risk or unexpected operator state changes.

---

## Architecture
- **`OperatorStatusDriftTrap.sol`**  
  Implements Drosera’s `ITrap` interface.  
  - `collect()` snapshots the current operator status and encodes it.  
  - `shouldRespond()` deterministically inspects encoded history and signals when a status change is detected.
- **`OperatorResponder.sol`**  
  Simple response contract that emits an `OperatorAlert` event when called.  
  In production, responders can trigger governance actions, alerts, or AVS-specific mitigations.
- **`drosera.toml`**  
  Configuration file for the Drosera relay to manage and route trap responses.

---

## Key Invariants
The trap detects:
- **Operator status drift**: If an operator’s status code (`uint8`) differs from the previously snapshotted status, the trap signals a response.
- Encoded payload returned by `shouldRespond` is:
  ```solidity
  abi.encode(address operator, uint8 oldStatus, uint8 newStatus, bytes32 tag)
````

where `tag` is fixed as `bytes32("OP_STATUS_DRIFT")`.

---

## Hoodi Testnet Integration

* **DelegationManager (Hoodi proxy)**:
  `0x867837a9722C512e0862d8c2E15b8bE220E8b87d`
  Used to fetch operator statuses.

* **Drosera relay address** (example):
  `0x91cB447BaFc6e0EA0F4Fe056F5a9b1F14bb06e5D`

Update `drosera.toml` with the correct deployed addresses for both the trap and responder.

---

## Deployment & Configuration

### 1. Build and Deploy

```bash
forge build
forge create src/OperatorStatusDriftTrap.sol:OperatorStatusDriftTrap --rpc-url https://ethereum-hoodi-rpc.publicnode.com --private-key $PK
forge create src/OperatorResponder.sol:OperatorResponder --rpc-url https://ethereum-hoodi-rpc.publicnode.com --private-key $PK
```

### 2. Configure the Trap

```bash
# Set delegation manager
cast send <TRAP> "setDelegationManager(address)" 0x867837a9722C512e0862d8c2E15b8bE220E8b87d --private-key $PK --rpc-url https://ethereum-hoodi-rpc.publicnode.com

# Add watched operator
cast send <TRAP> "addWatched(address)" 0xOPERATOR --private-key $PK --rpc-url https://ethereum-hoodi-rpc.publicnode.com

# Snapshot operator baseline
cast send <TRAP> "snapshotOperator(address)" 0xOPERATOR --private-key $PK --rpc-url https://ethereum-hoodi-rpc.publicnode.com
```

---

## Testing the Trap

### Collect Data

```bash
COLLECT_HEX=$(cast call <TRAP> "collect()" --rpc-url https://ethereum-hoodi-rpc.publicnode.com)
echo $COLLECT_HEX
```

### Run `shouldRespond`

```bash
cast call <TRAP> "shouldRespond(bytes[])" [$COLLECT_HEX] --rpc-url https://ethereum-hoodi-rpc.publicnode.com
```

### Decode Payload

If `shouldRespond` returns `true`, decode the payload:

```bash
cast abi-decode "(address,uint8,uint8,bytes32)" 0x<RESPONSE_HEX>
```

---

## Triggering the Responder

To manually test responder calls:

```bash
cast send <RESPONDER> "respondWithOperatorAlert(address,uint8,uint8,bytes32)" \
  0xOPERATOR 1 2 0x4f505f5354415455535f4452494654 \
  --private-key $PK --rpc-url https://ethereum-hoodi-rpc.publicnode.com
```

This will emit the `OperatorAlert` event with the detected drift.

---

## drosera.toml Example

```toml
ethereum_rpc = "https://ethereum-hoodi-rpc.publicnode.com"
drosera_rpc  = "https://relay.hoodi.drosera.io"
eth_chain_id = 560048
drosera_address = "0x91cB447BaFc6e0EA0F4Fe056F5a9b1F14bb06e5D"

[traps]

[traps.operator_status_drift]
path = "out/OperatorStatusDriftTrap.sol/OperatorStatusDriftTrap.json"
response_contract = "0xRESPONDER"   # replace after deployment
response_function = "respondWithOperatorAlert(address,uint8,uint8,bytes32)"
cooldown_period_blocks = 30
min_number_of_operators = 1
max_number_of_operators = 5
block_sample_size = 20
private_trap = true
whitelist = ["0x83cd7e5604ff5823734ddfbd82820c0965498284"]
address = "0xTRAP"  # replace after deployment
```

---
Do you want me to also include a **diagram (architecture / data flow)** in the README (ASCII or Mermaid), so it’s more visual when viewed on GitHub?
```
