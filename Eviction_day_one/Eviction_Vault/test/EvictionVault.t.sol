// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "forge-std/Test.sol";
import "../src/EvictionVault.sol";
import "../src/MerkleVerifier.sol";

contract EvictionVaultTest is Test {

    EvictionVault vault;

    address user = address(1);
    address signer = vm.addr(1);

    uint256 signerPrivateKey = 1;

    uint256 amount = 1 ether;

    bytes32 root;

    bytes32[] proof;

    function setUp() public {
        bytes32 leaf = MerkleVerifier.computeLeaf(user, amount);
        root = leaf;

        vault = new EvictionVault(root);

        vm.deal(address(vault), 10 ether);
    }

    function signMessage() internal returns (bytes memory) {

        bytes32 messageHash = keccak256(abi.encodePacked(user, amount));

        bytes32 ethHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                messageHash
            )
        );

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(signerPrivateKey, ethHash);

        return abi.encodePacked(r, s, v);
    }

    function testClaimSuccess() public {

        bytes memory signature = signMessage();

        vm.prank(user);

        vault.claim(
            amount,
            proof,
            signature,
            signer
        );

        assertTrue(vault.hasClaimed(user));
        assertEq(user.balance, amount);
    }

    function testClaimWithoutSignature() public {

        vm.prank(user);

        vault.claim(
            amount,
            proof,
            "",
            address(0)
        );

        assertTrue(vault.hasClaimed(user));
    }

    function testCannotClaimTwice() public {

        vm.prank(user);

        vault.claim(
            amount,
            proof,
            "",
            address(0)
        );

        vm.prank(user);

        vm.expectRevert(
            ClaimLogic.AlreadyClaimed.selector
        );

        vault.claim(
            amount,
            proof,
            "",
            address(0)
        );
    }

    function testInvalidSignature() public {

        bytes memory badSignature = hex"1234";

        vm.prank(user);

        vm.expectRevert();

        vault.claim(
            amount,
            proof,
            badSignature,
            signer
        );
    }

}