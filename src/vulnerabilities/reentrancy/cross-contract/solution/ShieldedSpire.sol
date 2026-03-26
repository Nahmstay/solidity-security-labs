// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// ShieldedSpire demonstrates the fixed version of the cross-contract 
// reentrancy vulnerability.
// Both contracts are protected:
// 1. ShieldedSpire uses CEI and ReentrancyGuard on withdraw
// 2. ShieldedRewards updates state before making external calls
// Together they eliminate the stale state window the attacker relied on.

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Contract A — fixed balance store
contract ShieldedSpire is ReentrancyGuard {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external nonReentrant {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "Nothing to withdraw"); // Check

        balances[msg.sender] = 0; // Effect

        (bool success, ) = msg.sender.call{value: amount}(""); // Interaction
        require(success, "Transfer failed");
    }
}

// Contract B — fixed reward distributor
contract ShieldedRewards is ReentrancyGuard {
    ShieldedSpire public spireVault;
    mapping(address => bool) public rewardClaimed;

    constructor(address _spireVault) {
        spireVault = ShieldedSpire(_spireVault);
    }

    function claimReward() external nonReentrant {
        require(spireVault.balances(msg.sender) > 0, "No balance"); // Check
        require(!rewardClaimed[msg.sender], "Already claimed"); // Check

        rewardClaimed[msg.sender] = true; // Effect

        (bool success, ) = msg.sender.call{value: 0.1 ether}(""); // Interaction
        require(success, "Reward failed");
    }
}