pragma solidity ^0.8.20;

interface IGovernanceGuard {
    function registerProposalSnapshot(bytes32 proposalId) external;
    function checkAndRecordDrain(uint256 amount) external;
}
