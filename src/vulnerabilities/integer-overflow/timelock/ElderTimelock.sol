// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

// Pre-0.8 integer overflow lab. extendSeal() adds to unlocksAt with no
// overflow check — a large enough additionalTime wraps it past 2^256 back
// to a tiny value, unsealing the vault.

contract ElderTimelock {
    address public elder;
    uint256 public unlocksAt;
    bool public isSealed;
    string public artifact;

    event SealExtended(address indexed by, uint256 newUnlocksAt);
    event VaultOpened(address indexed by, uint256 timestamp);

    constructor() {
        elder = msg.sender;
        unlocksAt = block.timestamp + 36500 days;
        isSealed = true;
        artifact = "A worn copper bracelet";
    }

    // VULNERABLE: no overflow check on the addition.
    function extendSeal(uint256 additionalTime) external {
        unlocksAt += additionalTime;
        emit SealExtended(msg.sender, unlocksAt);
    }

    function open() external {
        require(block.timestamp >= unlocksAt, "ElderTimelock: vault is sealed");
        isSealed = false;
        emit VaultOpened(msg.sender, block.timestamp);
    }

    function readArtifact() external view returns (string memory) {
        require(!isSealed, "ElderTimelock: vault is sealed");
        return artifact;
    }
}
