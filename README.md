# Solidity Security Labs

Hands-on smart contract vulnerability examples built with Foundry.

Each lab contains a vulnerable contract, an attacker contract, and a fixed version.
Clone it, run the tests, break things, understand why they broke.

Theory only gets you so far. At some point you have to start interacting with the contracts yourself.

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

---

## Vulnerabilities

| Vulnerability | Folder | Article |
|---|---|---|
| Reentrancy — Classic | `src/vulnerabilities/reentrancy/classic` | [Read](your-article-link) |
| Reentrancy — Cross-Function | `src/vulnerabilities/reentrancy/cross-function` | [Read](your-article-link) |
| Reentrancy — Cross-Contract | `src/vulnerabilities/reentrancy/cross-contract` | [Read](your-article-link) |

More coming as the series grows.

---

## Structure

Each vulnerability folder contains:

- `Vulnerable*.sol` — the flawed contract
- `*Attacker.sol` — the exploit
- `solution/Fixed*.sol` — the patched version

Tests live in `test/vulnerabilities/` mirroring the same structure.

---

## Who This Is For

Anyone learning smart contract security who wants something to actually run,
not just read about. If you found this through the blog, welcome.
If you stumbled in from somewhere else, the blog is at [Nahmstay on Medium](your-medium-link).

---

## Built With

- [Foundry](https://getfoundry.sh)
- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts)

---

*Nahmstay*
