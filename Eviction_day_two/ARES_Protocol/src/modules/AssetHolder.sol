// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract TreasuryVault is AccessControl, ReentrancyGuard {
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");

    event ETHExecuted(address indexed target, uint256 value);
    event ERC20Transferred(address indexed token, address indexed to, uint256 amount);
    event ETHReceived(address indexed sender, uint256 amount);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(EXECUTOR_ROLE, admin);
    }

    function execute(
        address target,
        uint256 value,
        bytes calldata data
    ) external onlyRole(EXECUTOR_ROLE) nonReentrant {
        require(target != address(0), "Zero target");
        Address.functionCallWithValue(target, data, value);
        emit ETHExecuted(target, value);
    }

    function safeTransferERC20(
        IERC20 token,
        address to,
        uint256 amount
    ) external onlyRole(EXECUTOR_ROLE) nonReentrant {
        require(to != address(0), "Zero recipient");
        SafeERC20.safeTransfer(token, to, amount);
        emit ERC20Transferred(address(token), to, amount);
    }

    receive() external payable {
        emit ETHReceived(msg.sender, msg.value);
    }
}