// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// SpireVault holds user balances and allows deposits and withdrawals.
// The vulnerability: withdraw sends ETH before zeroing the balance.
// This creates a window where MirageRewards reads a stale balance
// and pays out rewards the attacker has already claimed.

contract SpireVault {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "Nothing to withdraw");

        // Control passes to attacker here — balance not yet zeroed
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        balances[msg.sender] = 0;
    }
}
