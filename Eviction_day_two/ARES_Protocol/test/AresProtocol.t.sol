// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {ARESToken}          from "../src/modules/ARESToken.sol";
import {TreasuryVault}      from "../src/modules/AssetHolder.sol";
import {TreasuryAuthorizer} from "../src/modules/Verification.sol";
import {TreasuryExecutor}   from "../src/modules/Execution.sol";
import {GovernanceGuard}    from "../src/modules/GovernanceGuard.sol";
import {TimelockAres}       from "../src/modules/Delay.sol";

contract AresSecurityFocusedTest is Test {

    address admin    = makeAddr("admin");
    address guardian = makeAddr("guardian");
    address proposer = makeAddr("proposer");
    address attacker = makeAddr("attacker");
    address alice    = makeAddr("alice");

    uint256 signer1Pk = 0xA11CE;
    uint256 signer2Pk = 0xB0B;
    address signer1;
    address signer2;

    ARESToken          token;
    TreasuryVault      vault;
    TreasuryAuthorizer authorizer;
    TreasuryExecutor   executor;
    GovernanceGuard    guard;
    TimelockAres       timelock;

    uint256 constant INITIAL_SUPPLY   = 1_000_000e18;
    uint256 constant DAILY_LIMIT      = 100 ether;
    uint256 constant PROPOSAL_DEPOSIT = 0.1 ether;
    uint256 constant MIN_DELAY        = 2 days;
    uint256 constant THRESHOLD        = 2;

    function setUp() public {
        signer1 = vm.addr(signer1Pk);
        signer2 = vm.addr(signer2Pk);

        vm.startPrank(admin);

        token = new ARESToken(admin, INITIAL_SUPPLY);
        vault = new TreasuryVault(admin);
        guard = new GovernanceGuard(admin, DAILY_LIMIT, PROPOSAL_DEPOSIT);
        authorizer = new TreasuryAuthorizer(admin, address(token), THRESHOLD);
        executor = new TreasuryExecutor(address(vault), address(authorizer), address(guard), admin);

        address[] memory proposers = new address[](1); proposers[0] = proposer;
        address[] memory executors = new address[](1); executors[0] = address(0);

        timelock = new TimelockAres(MIN_DELAY, proposers, executors, admin, address(guard));

        vault.grantRole(vault.EXECUTOR_ROLE(), address(executor));
        vault.revokeRole(vault.EXECUTOR_ROLE(), admin);

        executor.grantRole(executor.TIMELOCK_ROLE(), address(timelock));
        executor.revokeRole(executor.TIMELOCK_ROLE(), admin);

        authorizer.grantRole(authorizer.EXECUTOR_ROLE(), address(executor));
        authorizer.revokeRole(authorizer.EXECUTOR_ROLE(), admin);

        guard.grantRole(guard.EXECUTOR_ROLE(), address(executor));
        guard.grantRole(guard.EXECUTOR_ROLE(), address(timelock));
        guard.grantRole(guard.GUARDIAN_ROLE(), guardian);

        authorizer.addSigner(signer1);
        authorizer.addSigner(signer2);

        vm.deal(address(vault), 1000 ether);
        token.transfer(address(authorizer), 100_000e18);

       
        authorizer.grantRole(authorizer.EXECUTOR_ROLE(), address(this));
        vault.grantRole(vault.EXECUTOR_ROLE(), address(this));

        vm.stopPrank();
    }

    function _domain() internal view returns (bytes32) {
        return keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes("ARES Treasury")),
            keccak256(bytes("1")),
            block.chainid,
            address(authorizer)
        ));
    }

    function _validSignatures(uint256 nonce, address target, uint256 value, bytes memory data) internal view returns (bytes[] memory sigs) {
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            _domain(),
            keccak256(abi.encode(
                keccak256("TreasuryAction(uint256 nonce,address target,uint256 value,bytes data)"),
                nonce, target, value, keccak256(data)
            ))
        ));

        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(signer1Pk, digest);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(signer2Pk, digest);

        bytes memory sig1 = abi.encodePacked(r1, s1, v1);
        bytes memory sig2 = abi.encodePacked(r2, s2, v2);

        sigs = new bytes[](2);
        sigs[signer1 < signer2 ? 0 : 1] = sig1;
        sigs[signer1 < signer2 ? 1 : 0] = sig2;
    }

    function test_Reentrancy_AttackerTriesToReenterVault() public {
        vm.expectRevert();
        vm.prank(attacker);
        vault.execute(alice, 1 ether, "");
    }

    function test_MerkleClaim_DoubleClaimSameRound_Reverts() public {
        bytes32 leaf = keccak256(abi.encodePacked(alice, uint256(100e18)));
        bytes32 root = leaf;

        vm.prank(admin);
        authorizer.setMerkleRoot(root);

        bytes32[] memory proof = new bytes32[](0);

        authorizer.claim(alice, 100e18, proof);

        vm.expectRevert("Already claimed this round");
        authorizer.claim(alice, 100e18, proof);
    }


    function test_InvalidSignature_Rejected() public {
        uint256 nonce = authorizer.currentNonce();
        bytes memory data = "";

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01", _domain(),
            keccak256(abi.encode(
            keccak256("TreasuryAction(uint256 nonce,address target,uint256 value,bytes data)"),
            nonce, alice, 0, keccak256(data)
            ))
        ));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signer1Pk, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        bytes[] memory sigs = new bytes[](2);
        sigs[0] = sig;
        sigs[1] = sig;

        vm.expectRevert();
        vm.prank(address(executor));
        authorizer.verifyThresholdSignatures(nonce, alice, 0, data, sigs);
    }

    function test_Timelock_PrematureExecution_Reverts() public {
        address[] memory targets   = new address[](1); 
        uint256[] memory values    = new uint256[](1); 
        bytes[][] memory sigs      = new bytes[][](1);
        
        
        targets[0]   = address(executor);
        values[0]    = 0;
        bytes[]   memory calldatas = new bytes[](1);  

        calldatas[0] = "";

        bytes memory payload = abi.encodeWithSelector(
            TreasuryExecutor.executeBatch.selector,
            targets, values, calldatas, sigs
        );

        address[] memory tTargets  = new address[](1); tTargets[0] = address(executor);
        uint256[] memory tValues   = new uint256[](1); tValues[0] = 0;
        bytes[]   memory tPayloads = new bytes[](1);   tPayloads[0] = payload;

        bytes32 salt = bytes32(uint256(777));

        vm.prank(proposer);
        timelock.scheduleBatch(tTargets, tValues, tPayloads, bytes32(0), salt, MIN_DELAY);

        vm.expectRevert();
        timelock.executeBatch(tTargets, tValues, tPayloads, bytes32(0), salt);
    }

    function test_Timelock_OperationReplay_Reverts() public {
        address[] memory tTargets = new address[](1); tTargets[0] = address(executor);
        uint256[] memory tValues = new uint256[](1); tValues[0] = 0;
        bytes[] memory tPayloads = new bytes[](1);
    
        tPayloads[0] = abi.encodeWithSelector(
        TreasuryExecutor.executeBatch.selector,
        new address[](0), new uint256[](0), new bytes[](0), new bytes[][](0)
        );
        bytes32 salt = bytes32(uint256(999));

        vm.prank(proposer);
        timelock.scheduleBatch(tTargets, tValues, tPayloads, bytes32(0), salt, MIN_DELAY);

        vm.expectRevert();
        vm.prank(proposer);
        timelock.scheduleBatch(tTargets, tValues, tPayloads, bytes32(0), salt, MIN_DELAY);
        }

    function test_Executor_UnauthorizedCaller_Reverts() public {
        address[] memory targets   = new address[](1);
        uint256[] memory values    = new uint256[](1);
        bytes[]   memory calldatas = new bytes[](1);
        bytes[][] memory sigs      = new bytes[][](1);

        vm.expectRevert();
        vm.prank(attacker);
        executor.executeBatch(targets, values, calldatas, sigs);
    }

    function test_DrainLimit_Exceeded_Reverts() public {
        address[] memory targets   = new address[](1); targets[0]   = alice;
        uint256[] memory values    = new uint256[](1); values[0]    = DAILY_LIMIT + 1;
        bytes[]   memory calldatas = new bytes[](1);   calldatas[0] = "";

        bytes[][] memory sigs = new bytes[][](1);
        sigs[0] = _validSignatures(authorizer.currentNonce(), alice, values[0], "");

        bytes memory payload = abi.encodeWithSelector(
            TreasuryExecutor.executeBatch.selector,
            targets, values, calldatas, sigs
        );

        address[] memory tTargets  = new address[](1); tTargets[0] = address(executor);
        bytes32 salt = bytes32(uint256(123));

        vm.prank(proposer);
        timelock.scheduleBatch(tTargets, new uint256[](1), new bytes[](1), bytes32(0), salt, MIN_DELAY);

        vm.warp(block.timestamp + MIN_DELAY + 10);

        vm.expectRevert();
        timelock.executeBatch(tTargets, new uint256[](1), new bytes[](1), bytes32(0), salt);
    }

    function test_Vault_DirectCallByNonExecutor_Reverts() public {
        vm.expectRevert();
        vm.prank(attacker);
        vault.execute(alice, 1 ether, "");
    }
}