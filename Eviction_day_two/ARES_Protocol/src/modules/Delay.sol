// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/governance/TimelockController.sol";
import {IGovernanceGuard} from "../interfaces/IGovernanceGuard.sol";

contract TimelockAres is TimelockController {
    address public guard;

    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin,
        address _guard
    ) TimelockController(minDelay, proposers, executors, admin) {
        guard = _guard;
    }

    function scheduleBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) public override {
        super.scheduleBatch(targets, values, payloads, predecessor, salt, delay);

        bytes32 operationId = hashOperationBatch(
            targets, values, payloads, predecessor, salt
        );
        IGovernanceGuard(guard).registerProposalSnapshot(operationId);
    }
}