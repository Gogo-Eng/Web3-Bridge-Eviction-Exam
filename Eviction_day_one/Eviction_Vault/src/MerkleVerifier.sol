// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

library MerkleVerifier {
    error InvalidMerkleProof();

    function verifyProof(
        bytes32 root,
        bytes32[] calldata proof,
        bytes32 leaf
    ) internal pure {
        if (!MerkleProof.verify(proof, root, leaf)) {
            revert InvalidMerkleProof();
        }
    }

    function computeLeaf(address account, uint256 value) internal pure returns (bytes32) {
        bytes32 leaf;
        assembly {
            mstore(0x00, account)
            mstore(0x20, value)
            leaf := keccak256(0x00, 0x34)   // 20 + 32 = 52 bytes
        }
        return leaf;
    }
}