## ARES Protocol Security Analysis

---

## Overview

The ARES treasury manages $500M+ in assets, making it a high-value target across every known DeFi attack class. This document maps each attack surface to the specific code mechanism that mitigates it, and honestly identifies risks that remain after mitigation.

Attack surfaces are grouped into five categories: cryptographic, execution flow, governance economic, distribution, and operational.

---

## Cryptographic Attack Surface

### Signature Replay

**Attack:** An attacker intercepts a valid EIP-712 signature and resubmits it in a later transaction to authorize a duplicate treasury action.

**Mitigation:** `TreasuryAuthorizer` maintains a global sequential nonce (`nextNonce`). Each call to `verifyThresholdSignatures()` requires the exact current nonce, marks it as used in `usedNonces[nonce]`, and increments `nextNonce`. A replayed signature carries an already-consumed nonce and is rejected with `"Nonce already used"`. The nonce is consumed before signature recovery ensuring that even a failed transaction burns the nonce and cannot be retried with the same signatures.

### Cross-Chain Replay

**Attack:** A signature valid on Ethereum mainnet is submitted on Arbitrum or another EVM chain where the same contracts are deployed, draining a parallel treasury.

**Mitigation:** EIP-712 domain separators include `block.chainid` as a parameter. The domain is constructed as `{name: 'ARES Treasury', version: '1', chainId: <current>, verifyingContract: <address>}`. A signature produced on chain 1 produces a different hash on chain 2, causing `ECDSA.recover()` to return a different (unregistered) address, which fails the `SIGNER_ROLE` check.

### Signature Malleability

**Attack:** An attacker takes a valid signature `(r, s, v)` and produces a second mathematically valid signature for the same message. Both signatures recover to the same address, allowing double-spend of a single authorization.

**Mitigation:** `ECDSA.recover()` from OpenZeppelin enforces canonical signatures, preventing signature malleability.

### Duplicate Signer in Threshold

**Attack:** A single compromised signer submits their signature multiple times in the `signatures[]` array to meet the threshold alone e.g. submitting 3 copies of one signature to satisfy a 3-of-5 threshold.

**Mitigation:** Signatures are required to be sorted by recovered signer address in strict ascending order. The check `require(recovered > lastSigner)` enforces that each recovered address is strictly greater than the previous.

---

## Execution Flow Attack Surface

### Reentrancy

**Attack:** A malicious target contract, when called by `TreasuryVault.execute()`, makes a recursive call back into the vault or executor before the first call completes, draining funds multiple times.

**Mitigation:** Both `TreasuryVault.execute()` and `TreasuryVault.safeTransferERC20()` are decorated with OpenZeppelin's `nonReentrant` modifier, which sets a locked flag before execution and clears it after. Any reentrant call reverts with `"ReentrancyGuard: reentrant call"`. `TreasuryExecutor.executeBatch()` also carries `nonReentrant` to prevent cross-contract reentrancy paths through the executor.

### Timelock Bypass

**Attack:** An attacker finds a path to call `TreasuryExecutor.executeBatch()` without going through `TimelockAres`, bypassing the mandatory delay.

**Mitigation:** `executeBatch()` is gated by `onlyRole(TIMELOCK_ROLE)`. Post-deployment, `TIMELOCK_ROLE` is granted only to the `TimelockAres` contract address. No human address holds this role. Even the `DEFAULT_ADMIN_ROLE` cannot call `executeBatch()` admin can only manage roles, not execute treasury actions directly.

### Proposal Replay

**Attack:** An already-executed timelock proposal is submitted again to re-execute the same treasury action.

**Mitigation:** `TimelockController` tracks every operation by its hash (`keccak256` of all parameters including salt). Once an operation reaches state `Done`, it can never be executed again the state machine only advances forward: `Unknown → Pending → Ready → Done`. 

### Batch Gas Griefing

**Attack:** A proposer submits a batch of MAX size with one action designed to consume nearly all remaining gas, causing later actions to fail and leaving the batch in a partial execution state.

**Mitigation:** `MAX_BATCH_SIZE = 10` limits batch length. Each action is verified and executed sequentially if any action reverts, the entire transaction reverts, leaving no partial state. Gas estimation tooling should simulate the full batch before submission.

---

## Governance Economic Attack Surface

### Flash Loan Governance Manipulation

**Attack:** An attacker borrows a massive token position via flash loan within a single block, uses it to pass a malicious governance proposal, then repays the loan all before any detection is possible.

**Mitigation:** `GovernanceGuard.registerProposalSnapshot()` records `block.number` at proposal creation time. Voting power must be evaluated at this historical snapshot, not at execution time. Because flash loans borrow and repay within one block, an attacker cannot hold tokens at the snapshot block and simultaneously pass the execution block the snapshot pre-dates any flash loan the attacker could take to influence the vote.

### Large Treasury Drain

**Attack:** Even with valid governance approval, a single compromised proposal drains the entire $500M treasury in one transaction.

**Mitigation:** `GovernanceGuard` enforces a `dailyDrainLimit`. `checkAndRecordDrain(amount)` is called before each vault transfer, accumulating `drainedToday` against the limit. After 24 hours, the counter resets. This limits worst-case loss from a governance capture to one day's limit, a configurable parameter set conservatively at deployment (e.g., $5M/day = 1% of treasury per day).

### Proposal Griefing

**Attack:** An attacker spams the timelock queue with thousands of malicious or nonsense proposals, filling the queue and preventing legitimate proposals from being processed, or forcing governance participants to spend gas cancelling them.

**Mitigation:** `GovernanceGuard` requires a `proposalDeposit` (ETH stake) to submit any proposal. The deposit is refunded on successful execution and slashed (retained) if the proposal is cancelled by a Guardian. This makes spam proposals economically costly an attacker must commit real capital for each proposal.

### Emergency Response

**Attack:** An exploit is detected in progress, but governance cannot respond faster than the minimum timelock delay.

**Mitigation:** `GUARDIAN_ROLE` holders (a separate security multisig with faster response requirements than the main governance multisig) can call `GovernanceGuard.emergencyPause()` to halt all treasury operations instantly. This is a break-glass mechanism only `DEFAULT_ADMIN_ROLE` can unpause, requiring full governance consensus to restore operations.

---

## Distribution Attack Surface

### Double Claim

**Attack:** A contributor submits a valid Merkle proof twice to claim their reward allocation twice.

**Mitigation:** `hasClaimed[currentRound][recipient]` is set to `true` before the token transfer executes (following Checks-Effects-Interactions). A second claim attempt for the same address in the same round fails at the `require(!hasClaimed[currentRound][recipient])` check. The state update precedes the external call, so reentrancy cannot reset the flag mid-execution.

### Merkle Root Manipulation

**Attack:** An attacker gains control of `setMerkleRoot()` and sets a root that proves arbitrary addresses with arbitrary amounts, allowing them to drain the distribution pool.

**Mitigation:** `setMerkleRoot()` is restricted to `DEFAULT_ADMIN_ROLE` the governance multisig. The root is published off-chain as a commitment before the transaction, allowing the community to verify it matches the intended distribution. The timelock on governance actions provides a window to detect and cancel a malicious root update before contributors can claim against it.

### Cross-Round Claim Blocking

**Attack:** A root update invalidates all previous `hasClaimed` mappings, allowing users who already claimed to claim again, or blocking users who haven't yet claimed from ever claiming.

**Mitigation:** The `hasClaimed` mapping is keyed by `(round, address)` — not just address. When `setMerkleRoot()` is called, `currentRound` increments, opening a fresh claim slate. Previous round data is preserved in storage; past claimants cannot reclaim in old rounds because those rounds are closed, and new-round claimants start fresh.

---

## Remaining Risks

Honest security analysis requires acknowledging what the system does not fully solve.

### Signer Collusion

If M-of-N signers collude (e.g., 3 of 5 in a 3-of-5 configuration), they can authorize any treasury action. The timelock provides a detection window but not prevention. Mitigated operationally by distributing signers across independent organizations and jurisdictions.

### Admin Key Compromise

`DEFAULT_ADMIN_ROLE` can add signers, lower the threshold, update the Merkle root, and pause/unpause. A compromised admin key is the highest-severity risk in the system. Mitigated by requiring admin to be a multisig with a higher threshold than the signer set.
