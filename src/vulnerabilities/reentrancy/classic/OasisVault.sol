// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Classic reentrancy vulnerability example. The attacker can call the withdraw function recursively before the balance is updated, allowing them to drain the contract's funds.
contract OasisVault {
    mapping(address => uint256) public balances;

    function deposit() public payable {
        require(msg.value > 0, "Deposit must be greater than 0");

        balances[msg.sender] += msg.value;
    }

    function withdraw(uint256 _amount) public {
        require(_amount <= balances[msg.sender], "Insufficient balance in the bank");

        (bool success,) = msg.sender.call{value: _amount}("");
        require(success, "Transfer failed.");

        unchecked {
            balances[msg.sender] -= _amount;
        }
    }
}
