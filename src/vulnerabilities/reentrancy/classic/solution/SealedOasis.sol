// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// SealedOasis demonstrates the fixed version of the classic reentrancy vulnerability.
// The contract uses two layers of protection:
// 1. Checks-Effects-Interactions (CEI) — state is updated before the external call
// 2. OpenZeppelin's ReentrancyGuard — locks the function for the duration of execution
// Even if an attacker attempts to call back in, the lock reverts the reentrant call.

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract SealedOasis is ReentrancyGuard {
    
    mapping(address => uint) public balances;

    function deposit() public payable {
        require(msg.value > 0, "Deposit must be greater than 0");
        balances[msg.sender] += msg.value;
    }

    // CEI applied: balance updated (Effect) before ETH is sent (Interaction)
    // nonReentrant modifier adds a second layer — any reentrant call hits a locked door
    function withdraw(uint _amount) public nonReentrant {
        require(_amount <= balances[msg.sender], "Insufficient balance"); // Check

        balances[msg.sender] -= _amount; // Effect

        (bool success, ) = msg.sender.call{value: _amount}(""); // Interaction
        require(success, "Transfer failed.");
    }
}