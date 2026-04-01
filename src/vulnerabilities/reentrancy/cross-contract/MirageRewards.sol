// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// MirageRewards reads SpireVault's balance to gate reward claims.
// The vulnerability: it trusts SpireVault's balance as truth.
// During a reentrant withdraw, that balance is stale — a mirage.
// The attacker claims rewards multiple times before the balance is zeroed.

import "./SpireVault.sol";

contract MirageRewards {
    SpireVault public spireVault;
    mapping(address => bool) public rewardClaimed;

    constructor(address _spireVault) {
        spireVault = SpireVault(_spireVault);
    }

    function claimReward() external {
        // Reads stale balance from SpireVault during reentrant attack
        require(spireVault.balances(msg.sender) > 0, "No balance");
        require(!rewardClaimed[msg.sender], "Already claimed");

        rewardClaimed[msg.sender] = true;

        (bool success,) = msg.sender.call{value: 0.1 ether}("");
        require(success, "Reward failed");
    }
}
