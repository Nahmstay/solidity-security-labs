// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// FortifiedDune demonstrates the fixed version of the cross-function 
// reentrancy vulnerability.
// The contract uses two layers of protection:
// 1. Checks-Effects-Interactions (CEI) — state is updated before the external call
// 2. OpenZeppelin's ReentrancyGuard — locks the function for the duration of execution
// Even if an attacker attempts to call back in, the lock reverts the reentrant call.

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract FortifiedDune is ReentrancyGuard {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function transfer(address _to, uint256 _amount) external {
        require(balances[msg.sender] >= _amount, "Insufficient balance");
        balances[msg.sender] -= _amount;
        balances[_to] += _amount;
    }

    function withdraw(uint256 amount) external nonReentrant {
        require(balances[msg.sender] >= amount, "Insufficient balance"); // Check

        balances[msg.sender] -= amount; // Effect

        (bool success, ) = msg.sender.call{value: amount}(""); // Interaction
        require(success, "Transfer failed");
    }
}