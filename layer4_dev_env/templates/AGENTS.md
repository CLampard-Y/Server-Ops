# Project Agent Guide

This project is part of the Solidity/ZK learning workspace.

## Rules

- Do not commit API keys, private keys, mnemonics, or RPC secrets.
- Prefer Foundry tests for Solidity changes.
- Keep generated artifacts such as `out/`, `cache/`, and `node_modules/` out of git.
- Treat the US dedicated server as the primary Solidity development and Codex host.
- Treat HK as the fallback/auxiliary development host.
- Reserve the `us-compute` profile for a future compute-only runner; when that runner is available, use it for heavy fuzzing or proving jobs.

## Useful Commands

```bash
forge test
forge test -vvv
forge fmt
```
