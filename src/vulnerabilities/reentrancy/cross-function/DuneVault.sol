// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Cross-function reentrancy vulnerability example. The attacker can call a
// function that reads stale state from another function, allowing them to
// drain the contract's funds before balances are updated.
contract DuneVault {
    mapping(address => uint256) public balances;

    function deposit() public payable {
        require(msg.value > 0, "Deposit must be greater than 0");
        balances[msg.sender] += msg.value;
    }

    function transfer(address _to, uint256 _amount) public {
        require(_amount <= balances[msg.sender], "Insufficient balance");
        balances[msg.sender] -= _amount;
        balances[_to] += _amount;
    }

    function withdraw(uint256 _amount) public {
        require(_amount <= balances[msg.sender], "Insufficient balance in the vault");

        (bool success,) = msg.sender.call{value: _amount}("");
        require(success, "Transfer failed.");

        balances[msg.sender] = 0;
    }
}
