// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Fixed version of ElderTimelock. Identical code — only the pragma changes.
// Solidity 0.8+ checked arithmetic reverts the overflowing addition in
// extendSeal() with Panic(0x11) instead of wrapping unlocksAt to zero.

contract SealedTimelock {
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

    function extendSeal(uint256 additionalTime) external {
        unlocksAt += additionalTime;
        emit SealExtended(msg.sender, unlocksAt);
    }

    function open() external {
        require(block.timestamp >= unlocksAt, "SealedTimelock: vault is sealed");
        isSealed = false;
        emit VaultOpened(msg.sender, block.timestamp);
    }

    function readArtifact() external view returns (string memory) {
        require(!isSealed, "SealedTimelock: vault is sealed");
        return artifact;
    }
}
