# ARES Protocol

A modular treasury execution system for managing on-chain assets securely.

---

## What It Does

ARES lets a protocol governance system propose, approve, and execute treasury transactions — with mandatory time delays, threshold signatures, and economic attack protections built in.

---

## Modules

| File | What it does |
|---|---|
| `ARESToken.sol` | The protocol token |
| `AssetHolder.sol` | Holds all funds (ETH + ERC20) |
| `Delay.sol` | Enforces a waiting period before execution |
| `Execution.sol` | Coordinates signature checks and fund dispatch |
| `Verification.sol` | Verifies multi-sig approvals and handles reward claims |
| `GovernanceGuard.sol` | Prevents drains, griefing, and flash loan attacks |

---

## How a Transaction Works

```
1. Signers sign the action off-chain (3-of-5 required)
2. Proposer queues it in the timelock + places a deposit
3. Community reviews during the delay window (48hrs minimum)
4. Anyone executes after the delay passes
5. Executor verifies signatures → checks drain limit → vault releases funds
```

---

## Setup

```bash
git clone <repo>
cd ARES_Protocol
forge install
forge build
forge test
```

---

## Deploy Order

```
1. ARESToken
2. TreasuryVault
3. GovernanceGuard
4. TreasuryAuthorizer
5. TreasuryExecutor
6. TimelockAres
```

---

## Key Security Rules

- No single address can move funds alone — threshold signatures required
- All actions wait a minimum of 48 hours before execution
- A guardian can pause the entire protocol instantly if an attack is detected
- Daily drain limit caps how much can leave the treasury per day
- Proposers must stake ETH — lost if their proposal is malicious

---

## License
MIT