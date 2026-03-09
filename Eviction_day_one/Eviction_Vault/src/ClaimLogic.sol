// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "./MerkleVerifier.sol";
import "./SignatureVerifier.sol";

abstract contract ClaimLogic {
    bytes32 public immutable merkleRoot;

    mapping(address => bool) public hasClaimed;

    event Claimed(address indexed user, uint256 amount);

    error AlreadyClaimed();

    constructor(bytes32 _merkleRoot) {
        merkleRoot = _merkleRoot;
    }

    function _claim(
        address user,
        uint256 amount,
        bytes32[] calldata proof,
        bytes calldata signature,
        address signer
    ) internal {
        if (hasClaimed[user]) revert AlreadyClaimed();

        bytes32 leaf = MerkleVerifier.computeLeaf(user, amount);
        MerkleVerifier.verifyProof(merkleRoot, proof, leaf);

        if (signature.length > 0 && signer != address(0)) {
            bytes32 messageHash = keccak256(abi.encodePacked(user, amount));
            SignatureVerifier.verify(messageHash, signature, signer);
        }

        hasClaimed[user] = true;

        emit Claimed(user, amount);
    }

    function _sendReward(address to, uint256 amount) internal virtual;
}