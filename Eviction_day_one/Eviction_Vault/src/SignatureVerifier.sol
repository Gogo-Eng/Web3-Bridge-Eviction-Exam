// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

library SignatureVerifier {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    error InvalidSignature();

    function verify(
        bytes32 messageHash,
        bytes calldata signature,
        address expectedSigner
    ) internal pure {
        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        address recovered = ECDSA.recover(ethSignedHash, signature);

        if (recovered != expectedSigner) revert InvalidSignature();
    }
}