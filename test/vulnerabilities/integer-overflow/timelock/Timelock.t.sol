// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../../../src/vulnerabilities/integer-overflow/timelock/solution/SealedTimelock.sol";

// ElderTimelock and TimelockExploit are compiled with Solc 0.7.6 (authentic
// pre-0.8 semantics), so this 0.8+ test file cannot import them directly.
// Instead we declare local interfaces and deploy from the compiled artifacts
// with vm.deployCode.

interface IElderTimelock {
    function elder() external view returns (address);
    function unlocksAt() external view returns (uint256);
    function isSealed() external view returns (bool);
    function artifact() external view returns (string memory);
    function extendSeal(uint256 additionalTime) external;
    function open() external;
    function readArtifact() external view returns (string memory);
}

interface ITimelockExploit {
    function vault() external view returns (address);
    function exploit() external;
    function readArtifact() external view returns (string memory);
}

contract IntegerOverflowTimelockTest is Test {
    IElderTimelock public elderTimelock;
    SealedTimelock public sealedTimelock;

    address public elder = makeAddr("elder");
    address public traveler = makeAddr("traveler");

    function setUp() public {
        // Deploy vulnerable contract (compiled as 0.7.6 via artifact)
        vm.prank(elder);
        address elderAddr = deployCode("ElderTimelock.sol:ElderTimelock");
        elderTimelock = IElderTimelock(elderAddr);

        // Deploy fixed contract (0.8.x, imported directly)
        vm.prank(elder);
        sealedTimelock = new SealedTimelock();

        console.log("=== SETUP ===");
        console.log("Elder sealed ElderTimelock until:", elderTimelock.unlocksAt());
        console.log("Elder sealed SealedTimelock until:", sealedTimelock.unlocksAt());
        console.log("Current block.timestamp:", block.timestamp);
    }

    // ================================================================
    // VULNERABLE: Overflow attack succeeds on ElderTimelock
    // The traveler calls extendSeal() with a massive additionalTime,
    // wrapping unlocksAt past 2^256 back to 0. The open() check then
    // passes trivially because block.timestamp >= 0.
    // ================================================================
    function test_OverflowAttackSucceeds_ElderTimelock() public {
        console.log("");
        console.log("=== OVERFLOW ATTACK: ElderTimelock ===");
        console.log("Step 1: Traveler deploys TimelockExploit");

        vm.prank(traveler);
        address exploitAddr =
            deployCode("TimelockExploit.sol:TimelockExploit", abi.encode(address(elderTimelock)));
        ITimelockExploit exploit = ITimelockExploit(exploitAddr);

        console.log("Step 2: Record state before the attack");
        console.log("  unlocksAt:               ", elderTimelock.unlocksAt());
        console.log("  block.timestamp:         ", block.timestamp);
        console.log("  isSealed:                ", elderTimelock.isSealed());

        console.log("Step 3: Traveler calls exploit()");
        console.log("  -> computes extra = type(uint256).max - unlocksAt + 1");
        console.log("  -> calls extendSeal(extra)");
        console.log("  -> unlocksAt += extra wraps past 2^256 to 0 (no revert in 0.7.x)");
        console.log("  -> calls open(): block.timestamp >= 0 passes trivially");
        console.log("  -> vault opens");

        vm.prank(traveler);
        exploit.exploit();

        console.log("Step 4: Check the damage");
        console.log("  unlocksAt:               ", elderTimelock.unlocksAt());
        console.log("  isSealed:                ", elderTimelock.isSealed());
        console.log("  artifact read:           ", elderTimelock.readArtifact());

        // unlocksAt wrapped cleanly to 0
        assertEq(elderTimelock.unlocksAt(), 0, "Attack failed: unlocksAt did not wrap to 0");

        // Vault is open
        assertFalse(elderTimelock.isSealed(), "Attack failed: vault is still sealed");

        // Artifact is now readable
        assertEq(
            elderTimelock.readArtifact(),
            "A worn copper bracelet",
            "Attack failed: artifact not readable"
        );

        console.log("");
        console.log("ATTACK SUCCEEDED: The traveler opened a vault meant to stay sealed for 100 years");
        console.log("  The key: extendSeal() adds to unlocksAt with no overflow check");
        console.log("  A crafted extra wraps unlocksAt past 2^256 back to 0");
        console.log("  The open() time check becomes trivially satisfiable");
    }

    // ================================================================
    // FIXED: Overflow attack fails on SealedTimelock
    // Solidity 0.8+ checked arithmetic reverts with Panic(0x11) when
    // extendSeal()'s addition overflows. State remains untouched.
    // ================================================================
    function test_OverflowAttackFails_SealedTimelock() public {
        console.log("");
        console.log("=== OVERFLOW ATTACK ATTEMPT: SealedTimelock ===");

        uint256 unlocksAtBefore = sealedTimelock.unlocksAt();
        console.log("Step 1: SealedTimelock state before:");
        console.log("  unlocksAt:               ", unlocksAtBefore);
        console.log("  isSealed:                ", sealedTimelock.isSealed());

        // Same overflow math the TimelockExploit contract uses
        uint256 extra = type(uint256).max - unlocksAtBefore + 1;

        console.log("Step 2: Traveler calls extendSeal(huge value)");
        console.log("  -> unlocksAt += extra would overflow");
        console.log("  -> 0.8+ checked arithmetic reverts with Panic(0x11)");
        console.log("  -> transaction unwinds, state unchanged");

        vm.prank(traveler);
        vm.expectRevert(stdError.arithmeticError);
        sealedTimelock.extendSeal(extra);

        console.log("Step 3: SealedTimelock state after:");
        console.log("  unlocksAt:               ", sealedTimelock.unlocksAt());
        console.log("  isSealed:                ", sealedTimelock.isSealed());

        // State unchanged
        assertEq(sealedTimelock.unlocksAt(), unlocksAtBefore, "unlocksAt changed despite revert");
        assertTrue(sealedTimelock.isSealed(), "Vault should still be sealed");

        // open() still reverts because the real unlock time is far in the future
        vm.expectRevert("SealedTimelock: vault is sealed");
        sealedTimelock.open();

        console.log("");
        console.log("ATTACK BLOCKED: 0.8+ checked arithmetic killed the overflow exploit");
        console.log("  extendSeal() reverted on the overflowing addition");
        console.log("  unlocksAt stayed far in the future, vault stayed sealed");
    }

    // ================================================================
    // NORMAL USAGE: Legitimate unlock after time passes
    // ================================================================
    function test_NormalOpen_ElderTimelock() public {
        console.log("");
        console.log("=== NORMAL OPEN TEST: ElderTimelock ===");
        console.log("  unlocksAt:                ", elderTimelock.unlocksAt());
        console.log("  block.timestamp (before): ", block.timestamp);

        // Warp past the unlock time — the legitimate way in
        vm.warp(elderTimelock.unlocksAt() + 1);

        console.log("  block.timestamp (after):  ", block.timestamp);

        elderTimelock.open();

        assertFalse(elderTimelock.isSealed(), "Normal open failed");
        console.log("  NORMAL OPEN SUCCEEDED");
    }

    function test_NormalOpen_SealedTimelock() public {
        console.log("");
        console.log("=== NORMAL OPEN TEST: SealedTimelock ===");
        console.log("  unlocksAt:                ", sealedTimelock.unlocksAt());
        console.log("  block.timestamp (before): ", block.timestamp);

        vm.warp(sealedTimelock.unlocksAt() + 1);

        console.log("  block.timestamp (after):  ", block.timestamp);

        sealedTimelock.open();

        assertFalse(sealedTimelock.isSealed(), "Normal open failed on SealedTimelock");
        console.log("  NORMAL OPEN SUCCEEDED");
    }

    // ================================================================
    // NORMAL USAGE: extendSeal adds correctly when input is reasonable
    // ================================================================
    function test_NormalExtendSeal_SealedTimelock() public {
        console.log("");
        console.log("=== NORMAL EXTEND TEST: SealedTimelock ===");

        uint256 unlocksAtBefore = sealedTimelock.unlocksAt();
        console.log("  unlocksAt before extend: ", unlocksAtBefore);

        sealedTimelock.extendSeal(365 days);

        console.log("  unlocksAt after extend:  ", sealedTimelock.unlocksAt());

        assertEq(
            sealedTimelock.unlocksAt(), unlocksAtBefore + 365 days, "extendSeal did not add correctly"
        );
        console.log("  NORMAL EXTEND SUCCEEDED");
    }

    // ================================================================
    // EARLY OPEN: Before unlock time, open() reverts on both vaults
    // ================================================================
    function test_OpenBeforeUnlock_ElderTimelock() public {
        console.log("");
        console.log("=== EARLY OPEN TEST: ElderTimelock ===");
        console.log("  block.timestamp: ", block.timestamp);
        console.log("  unlocksAt:       ", elderTimelock.unlocksAt());

        vm.expectRevert("ElderTimelock: vault is sealed");
        elderTimelock.open();

        console.log("  OPEN REVERTED AS EXPECTED");
    }

    function test_OpenBeforeUnlock_SealedTimelock() public {
        console.log("");
        console.log("=== EARLY OPEN TEST: SealedTimelock ===");
        console.log("  block.timestamp: ", block.timestamp);
        console.log("  unlocksAt:       ", sealedTimelock.unlocksAt());

        vm.expectRevert("SealedTimelock: vault is sealed");
        sealedTimelock.open();

        console.log("  OPEN REVERTED AS EXPECTED");
    }
}
