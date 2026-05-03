# Project Agent Guide

This project is part of the Solidity/ZK learning workspace.

## Rules

- Do not commit API keys, private keys, mnemonics, or RPC secrets.
- Prefer Foundry tests for Solidity changes.
- Keep generated artifacts such as `out/`, `cache/`, and `node_modules/` out of git.
- For heavy fuzzing or proving jobs, sync to the US compute runner instead of running on the HK dev host.

## Useful Commands

```bash
forge test
forge test -vvv
forge fmt
```
