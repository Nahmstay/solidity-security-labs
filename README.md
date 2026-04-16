# Solidity Security Labs

Hands-on smart contract vulnerability examples built with Foundry.

Each lab contains a vulnerable contract, an attacker contract, and a fixed version.
Clone it, run the tests, break things, understand why they broke.

---

## Getting Started
```bash
git clone https://github.com/nahmstay/solidity-security-labs
cd solidity-security-labs
forge install
forge test
```

Run with verbose output to see exactly what's happening at each step:
```bash
forge test -vvv
```

Tests include step-by-step logs showing exactly where the exploit lands and where the fix stops it.

---

## Vulnerabilities

| Vulnerability | Folder | Article |
|---|---|---|
| Reentrancy — Classic, Cross-Function, Cross-Contract | `src/vulnerabilities/reentrancy` | [Read](https://medium.com/@nahmstay/reentrancy-i-still-write-cei-every-time-5cdb28d1be84) |
| Integer Overflow — Pre-0.8 Timelock | `src/vulnerabilities/integer-overflow` | [Read](https://medium.com/@nahmstay/integer-overflow-the-math-that-breaks-everything-10cce3376a52) |

More coming as the series grows.

---

## Structure

Each vulnerability folder contains three contracts:

- The vulnerable contract (e.g. `ElderTimelock.sol`, `OasisVault.sol`)
- The exploit (e.g. `TimelockExploit.sol`, `EchoAttacker.sol`)
- The patched version under `solution/` (e.g. `SealedTimelock.sol`, `SealedOasis.sol`)

Naming is thematic per lab, not mechanical. Tests live in `test/vulnerabilities/` mirroring the same structure.

The integer-overflow lab mixes Solidity 0.7 (vulnerable + exploit) and 0.8 (fix) in the same project. Foundry compiles each file under its own pragma — don't pin a single `solc` version in `foundry.toml` or the 0.7 contracts will fail to build.

---

## Who This Is For

Anyone learning smart contract security who wants something to actually run,
not just read about. If you found this through the blog, welcome.
If you stumbled in from somewhere else, each vulnerability has a matching writeup at [Nahmstay on Medium](https://medium.com/@nahmstay).

---

## Built With

- [Foundry](https://getfoundry.sh)
- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts)

---

*Nahmstay*