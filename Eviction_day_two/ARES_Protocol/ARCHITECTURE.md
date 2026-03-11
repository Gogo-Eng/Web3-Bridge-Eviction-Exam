## ARES Protocol Architecture Design

---

 ### Overview

ARES Protocol is a modular, security focused treasury execution system designed to manage $500M+ in on-chain assets. The protocol replaces monolithic vault designs, with a layered architecture where each module has a single, well defined responsibility and no module can act unilaterally to move funds.

The  Architecture is in such a way that an attacker who compromises one layer still faces multiple independent barriers before any capital can be moved. Every treasury action must pass through cryptographic authorization, a mandatory time delay, role-gated execution, and physical vault access controls before funds leave the protocol.

---

### System Architecture

ARES is composed of six independent Solidity modules organized into a strict call hierarchy. Capital flows only in one direction through the stack — from governance intent at the top, down to the vault at the bottom.

### Call Flow Hierarchy

```
Governance / Off-chain Signers (EIP-712 threshold signatures) -> TreasuryAuthorizer (verified action) -> TimelockAres (after minDelay) -> TreasuryExecutor(batch dispatch) -> TreasuryVault -> External Targets / Recipients
```

The `GovernanceGuard` module sits independently to this flow, acting as a cross-cutting policy enforcer that any module can consult before proceeding.

---

### Module Separation

Each module owns exactly one concern. This is intentional mixing concerns is how historical protocols introduced vulnerabilities where an upgrade to one feature silently broke another.

| Module | File | Single Responsibility |
|---|---|---|
| ARESToken | ARESToken.sol | Protocol native token, minting and supply control |
| TreasuryVault | AssetHolder.sol | Physical custody of ETH and ERC20 assets |
| TimelockAres | Delay.sol | Mandatory time delay between proposal and execution |
| TreasuryExecutor | Execution.sol | Batch orchestration, dispatches verified actions to vault |
| TreasuryAuthorizer | Verification.sol | Threshold signature verification and Merkle reward claims |
| GovernanceGuard | GovernanceGuard.sol | Economic attack prevention, drain limits, pause, deposits |

---

## Security Boundaries

Security boundaries in ARES are enforced through role-based access control at every module boundary. Each modules verifies the caller holds the appropriate role before proceeding.

###  Boundary: Vault

`TreasuryVault` is the innermost boundary. It will only accept calls from an address holding `EXECUTOR_ROLE`, which is set to `TreasuryExecutor` and nothing else post-deployment. Even if an attacker compromises governance, they cannot call the vault directly they must go through the executor, which enforces the timelock and signature checks.

### Boundary: Executor

`TreasuryExecutor` only accepts calls from an address holding `TIMELOCK_ROLE`, which is set to the `TimelockAres` contract. This means no human including the admin multisig can bypass the timelock to call `executeBatch()` directly.

### Boundary: Authorizer

`TreasuryAuthorizer`'s `verifyThresholdSignatures()` is restricted to `EXECUTOR_ROLE`. This prevents anyone from calling it to consume nonces out of sequence or fabricate verification events.

### Boundary: Timelock

`TimelockAres` inherits from OpenZeppelin's `TimelockController`, which enforces that only `PROPOSER_ROLE` addresses can queue actions, and only after `minDelay` has passed can any `EXECUTOR_ROLE` address execute them. The contract tracks operation state as a hash once executed, an operation is permanently marked `Done` and cannot be replayed.

---

## Trust Assumptions

Every protocol makes trust assumptions. ARES makes the following explicit:

### Threshold Signer Set

The system assumes that fewer than the threshold number of registered signers are compromised at any given time. With a 3-of-5 configuration, the system tolerates up to 2 compromised signers. If 3 or more collude, they can authorize arbitrary treasury actions mitigated by the timelock giving observers time to detect and respond.

### Admin Multisig

The `DEFAULT_ADMIN_ROLE` across all modules is assumed to be held by a secure multisig with a signing threshold higher than day-to-day operations. Admin can add/remove signers, update thresholds, and change the Merkle root. A compromised admin is the highest-trust assumption in the system.

### Timelock Delay

The security of the time delay depends on the community's ability to detect and respond to malicious proposals within the `minDelay` window. If `minDelay` is set too low (e.g., 1 hour), the response window is insufficient for a $500M treasury. A minimum of 48–72 hours is recommended for production deployment.

### EIP-712 Domain

The system assumes signers verify the domain separator before signing. A signer who blindly signs any digest could be tricked into authorizing a malicious action. This is a social/operational assumption, not a code assumption.

### Merkle Root Integrity

The Merkle root for contributor distributions is set by the admin. The system assumes the admin publishes correct roots that reflect actual contributor entitlements. An incorrect root would allow unauthorized claims or deny legitimate ones.

---

## Folder Structure

```
src/
  interfaces/
    ITreasuryVault.sol
    ITreasuryAuthorizer.sol
  modules/
    ARESToken.sol
    AssetHolder.sol
    Delay.sol
    Execution.sol
    Verification.sol
    GovernanceGuard.sol
test/
script/
README.md
ARCHITECTURE.md
SECURITY.md
```
