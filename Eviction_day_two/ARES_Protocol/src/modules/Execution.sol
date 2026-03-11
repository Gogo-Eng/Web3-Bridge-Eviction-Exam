// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ITreasuryVault} from "../interfaces/ITreasuryVault.sol";
import {ITreasuryAuthorizer} from "../interfaces/ITreasuryAuthorizer.sol";

contract TreasuryExecutor is AccessControl, ReentrancyGuard {
    bytes32 public constant TIMELOCK_ROLE = keccak256("TIMELOCK_ROLE");
    uint256 public constant MAX_BATCH_SIZE = 10;

    address public vault;
    address public authorizer;

    event BatchExecuted(address indexed initiator, uint256 actionCount);

    constructor(address _vault, address _authorizer, address admin) {
        vault = _vault;
        authorizer = _authorizer;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(TIMELOCK_ROLE, admin);
    }

    function executeBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        bytes[][] calldata signatures
    ) external onlyRole(TIMELOCK_ROLE) nonReentrant {
        require(
            targets.length == values.length &&
            targets.length == calldatas.length &&
            targets.length == signatures.length,
            "Length mismatch"
        );
        require(targets.length <= MAX_BATCH_SIZE, "Batch too large");
        require(targets.length > 0, "Empty batch");

        uint256 batchStartNonce = ITreasuryAuthorizer(authorizer).currentNonce();

        for (uint256 i = 0; i < targets.length; i++) {
            ITreasuryAuthorizer(authorizer).verifyThresholdSignatures(
                batchStartNonce + i,
                targets[i],
                values[i],
                calldatas[i],
                signatures[i]
            );

            ITreasuryVault(vault).execute(targets[i], values[i], calldatas[i]);
        }

        emit BatchExecuted(msg.sender, targets.length);
    }
}