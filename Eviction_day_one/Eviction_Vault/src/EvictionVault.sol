// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "./ClaimLogic.sol";

contract EvictionVault is ClaimLogic {

    constructor(bytes32 _merkleRoot) ClaimLogic(_merkleRoot) {}

    function _sendReward(address to, uint256 amount) internal override {
        (bool success, ) = payable(to).call{value: amount}("");
        require(success, "Reward transfer failed");
    }

    function claim(
        uint256 amount,
        bytes32[] calldata proof,
        bytes calldata signature,
        address signer
    ) external {
        _claim(msg.sender, amount, proof, signature, signer);
        _sendReward(msg.sender, amount);
    }

    receive() external payable {}
}