// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract GovernanceGuard is AccessControl, Pausable {
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");

    mapping(bytes32 => uint256) public proposalSnapshots;

    uint256 public dailyDrainLimit;
    uint256 public drainedToday;
    uint256 public lastDrainReset;

    uint256 public proposalDeposit;
    mapping(bytes32 => address) public depositOwner;
    mapping(bytes32 => bool) public depositRefunded;

    event GuardTriggered(string reason);
    event DailyLimitUpdated(uint256 newLimit);
    event DrainRecorded(uint256 amount, uint256 totalToday);
    event ProtocolPaused(address guardian);
    event ProtocolUnpaused(address guardian);
    event DepositPlaced(bytes32 indexed proposalId, address proposer, uint256 amount);
    event DepositRefunded(bytes32 indexed proposalId, address proposer);
    event DepositSlashed(bytes32 indexed proposalId, address proposer);

    constructor(
        address admin,
        uint256 _dailyDrainLimit,
        uint256 _proposalDeposit
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GUARDIAN_ROLE, admin);
        _grantRole(EXECUTOR_ROLE, admin);

        dailyDrainLimit = _dailyDrainLimit;
        proposalDeposit = _proposalDeposit;
        lastDrainReset = block.timestamp;
    }

    function registerProposalSnapshot(bytes32 proposalId) external onlyRole(EXECUTOR_ROLE) {
        require(proposalSnapshots[proposalId] == 0, "Already registered");
        proposalSnapshots[proposalId] = block.number;
        emit GuardTriggered("Snapshot registered");
    }

    function getProposalSnapshot(bytes32 proposalId) external view returns (uint256) {
        return proposalSnapshots[proposalId];
    }

        function checkAndRecordDrain(uint256 amount) external onlyRole(EXECUTOR_ROLE) whenNotPaused {
        if (block.timestamp >= lastDrainReset + 1 days) {
            drainedToday = 0;
            lastDrainReset = block.timestamp;
        }

        require(drainedToday + amount <= dailyDrainLimit, "Daily drain limit exceeded");
        drainedToday += amount;

        emit DrainRecorded(amount, drainedToday);
    }

    function updateDailyLimit(uint256 newLimit) external onlyRole(DEFAULT_ADMIN_ROLE) {
        dailyDrainLimit = newLimit;
        emit DailyLimitUpdated(newLimit);
    }


    function emergencyPause() external onlyRole(GUARDIAN_ROLE) {
        _pause();
        emit ProtocolPaused(msg.sender);
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
        emit ProtocolUnpaused(msg.sender);
    }

    function placeDeposit(bytes32 proposalId) external payable {
        require(msg.value >= proposalDeposit, "Insufficient deposit");
        require(depositOwner[proposalId] == address(0), "Deposit already placed");
        depositOwner[proposalId] = msg.sender;
        emit DepositPlaced(proposalId, msg.sender, msg.value);
    }

    function refundDeposit(bytes32 proposalId) external onlyRole(EXECUTOR_ROLE) {
        address owner = depositOwner[proposalId];
        require(owner != address(0), "No deposit found");
        require(!depositRefunded[proposalId], "Already refunded");
        depositRefunded[proposalId] = true;

        (bool success, ) = payable(owner).call{value: proposalDeposit}("");
        require(success, "Refund failed");

        emit DepositRefunded(proposalId, owner);
}

    function slashDeposit(bytes32 proposalId) external onlyRole(GUARDIAN_ROLE) {
        require(depositOwner[proposalId] != address(0), "No deposit found");
        require(!depositRefunded[proposalId], "Already refunded");
        depositRefunded[proposalId] = true;
        emit DepositSlashed(proposalId, depositOwner[proposalId]);
    }

    receive() external payable {}
}
