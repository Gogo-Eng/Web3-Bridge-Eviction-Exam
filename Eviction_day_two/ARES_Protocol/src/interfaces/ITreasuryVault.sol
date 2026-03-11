// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITreasuryVault {
    function execute(address target, uint256 value, bytes calldata data) external;
}