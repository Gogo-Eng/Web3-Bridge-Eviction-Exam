// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITreasuryAuthorizer{
    function verifyThresholdSignatures(uint256 nonce, address target, uint256 value, bytes calldata data, bytes[] calldata signatures) external;
    function currentNonce() external view returns (uint256);
}