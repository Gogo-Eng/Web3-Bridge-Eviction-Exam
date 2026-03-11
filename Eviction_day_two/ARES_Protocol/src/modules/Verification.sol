// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TreasuryAuthorizer is AccessControl, EIP712, Nonces {
    using SafeERC20 for IERC20;

    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");

    bytes32 private constant ACTION_TYPEHASH = keccak256("TreasuryAction(uint256 nonce,address target,uint256 value,bytes data)");

    uint256 public threshold;
    uint256 public signerCount;

   
    IERC20 public rewardToken;
    uint256 public currentRound;
    bytes32 public merkleRoot;
    mapping(uint256 => mapping(address => bool)) public hasClaimed;

    mapping(uint256 => bool) public usedNonces;
    uint256 public nextNonce;

    event MerkleRootUpdated(uint256 indexed round, bytes32 newRoot);
    event RewardClaimed(uint256 indexed round, address indexed recipient, uint256 amount);
    event ThresholdUpdated(uint256 newThreshold);
    event SignerAdded(address signer);
    event SignerRemoved(address signer);

    constructor(
        address admin,
        address _rewardToken,
        uint256 _threshold
    ) EIP712("ARES Treasury", "1") {
        require(_threshold > 0, "Threshold must be > 0");
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(EXECUTOR_ROLE, admin);

        rewardToken = IERC20(_rewardToken);
        threshold = _threshold;
    }


    function addSigner(address signer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(signer != address(0), "Zero address");
        require(!hasRole(SIGNER_ROLE, signer), "Already a signer");
        _grantRole(SIGNER_ROLE, signer);
        signerCount++;
        emit SignerAdded(signer);
    }

    function removeSigner(address signer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(hasRole(SIGNER_ROLE, signer), "Not a signer");
        require(signerCount - 1 >= threshold, "Would break threshold");
        _revokeRole(SIGNER_ROLE, signer);
        signerCount--;
        emit SignerRemoved(signer);
    }

    function updateThreshold(uint256 newThreshold) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newThreshold > 0, "Must be > 0");
        require(newThreshold <= signerCount, "Exceeds signer count");
        threshold = newThreshold;
        emit ThresholdUpdated(newThreshold);
    }

    function verifyThresholdSignatures(
        uint256 nonce,
        address target,
        uint256 value,
        bytes calldata data,
        bytes[] calldata signatures
    ) external onlyRole(EXECUTOR_ROLE) {
        require(!usedNonces[nonce], "Nonce already used");
        require(nonce == nextNonce, "Nonce out of order");
        usedNonces[nonce] = true;
        nextNonce++;

        require(signatures.length >= threshold, "Below threshold");

        bytes32 structHash = keccak256(abi.encode(
            ACTION_TYPEHASH,
            nonce,
            target,
            value,
            keccak256(data)
        ));
        bytes32 digest = _hashTypedDataV4(structHash);

        address lastSigner = address(0);

        for (uint256 i = 0; i < signatures.length; i++) {
            address recovered = ECDSA.recover(digest, signatures[i]);

            require(hasRole(SIGNER_ROLE, recovered), "Not an authorized signer");

            require(recovered > lastSigner, "Duplicate or unsorted signer");
            lastSigner = recovered;
        }
    }

    function currentNonce() external view returns (uint256) {
        return nextNonce;
    }

    function setMerkleRoot(bytes32 newRoot) external onlyRole(DEFAULT_ADMIN_ROLE) {
        currentRound++;
        merkleRoot = newRoot;
        emit MerkleRootUpdated(currentRound, newRoot);
    }

    function claim(
        address recipient,
        uint256 amount,
        bytes32[] calldata proof
    ) external {
        require(!hasClaimed[currentRound][recipient], "Already claimed this round");

        bytes32 leaf = keccak256(abi.encodePacked(recipient, amount));
        require(MerkleProof.verify(proof, merkleRoot, leaf), "Invalid proof");

        hasClaimed[currentRound][recipient] = true;
        rewardToken.safeTransfer(recipient, amount);

        emit RewardClaimed(currentRound, recipient, amount);
    }

    function hasClaimedCurrentRound(address user) external view returns (bool) {
        return hasClaimed[currentRound][user];
    }
}