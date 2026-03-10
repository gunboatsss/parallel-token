# AGENTS.md

## Project Overview

This is a Foundry (Solidity) project using the Solady library for smart contract development. The project implements a ParallelToken contract with mint/burn functionality and push/pull transfer patterns.

## Build, Lint, and Test Commands

### Build
```bash
forge build
forge build --sizes  # Build with contract size output
```

### Test
```bash
forge test              # Run all tests
forge test -vvv        # Run tests with verbose output
forge test -vvv --match-test TestName  # Run single test
forge test --match-contract ContractName  # Run tests for specific contract
forge test -vv --via-ir # Run with IR pipeline for optimization checks
```

### Format
```bash
forge fmt              # Format code
forge fmt --check      # Check formatting (used in CI)
```

### Gas Snapshots
```bash
forge snapshot         # Generate gas snapshots
forge snapshot --check # Compare against existing snapshots
```

### Other Commands
```bash
anvil                  # Start local Ethereum node
cast <subcommand>      # Interact with EVM contracts
chisel                 # Solidity REPL
```

### CI Pipeline
The project runs in CI:
1. `forge fmt --check` - Verify formatting
2. `forge build --sizes` - Build with contract sizes
3. `forge test -vvv` - Run tests verbosely

## Code Style Guidelines

### General Conventions
- **Solidity Version**: 0.8.33
- **License**: AGPL-3.0 for contracts, UNLICENSED for tests
- **No code comments** unless explaining complex logic (per project convention)
- Run `forge fmt` before committing

### Naming Conventions
- **Contracts/Structs**: CapWords (e.g., `ParallelToken`, `TokenData`)
- **Events**: CapWords with past tense (e.g., `Mint`, `Burn`, `Transfer`)
- **Functions/Variables**: snake_case (e.g., `mint`, `idToTokenData`, `nonces`)
- **Constants**: UPPER_SNAKE_CASE
- **Interfaces**: Prefix with `I` (e.g., `IERC20`)
- **Private functions**: Prefix with underscore (e.g., `_push`, `_mint`)

### Imports
- Use explicit imports: `import {Function} from "library/path.sol";`
- Solady imports: `"solady/utils/SafeTransferLib.sol"`
- Forge-std imports: `"forge-std/Test.sol"`
- Local imports: `"src/ContractName.sol"`

### Types
- Use explicit types (e.g., `uint256` not `uint`)
- Use `address` for addresses
- Use `bool` for booleans
- Use `bytes calldata` for read-only bytes
- Use `bytes memory` for modifiable bytes
- Use `uint256` for loop counters (not `uint` or `uint8`)

### Error Handling
- Use `require(condition, "error message")` for validation
- Use `require(condition)` for internal checks without messages
- Custom errors recommended for complex validation (not used in this project)

### Function Design
- Explicitly return `bool` for functions that could fail (e.g., `returns (bool)`)
- Use `public` for externally callable functions
- Use `internal`/`private` for internal logic
- Use `calldata` for function parameters that are read-only arrays
- Use `memory` for dynamically-sized arrays that need modification
- Cache array length in loops: `uint256 length = _id.length;`

### Contract Patterns
- Follow checks-effects-interactions pattern
- Emit events for all state changes
- Use SafeTransferLib for ERC20 transfers (from Solady)
- Clear storage slots when burning (set to address(0) or 0)

### Testing
- Use forge-std Test contract
- Create helper contracts for mock tokens (e.g., `TokenA is ERC20`)
- Use `vm.startPrank(address)` for caller spoofing
- Use `makeAddr("name")` for creating addresses
- Test file naming: `{Contract}.t.sol`
- Test contract naming: `{Contract}Test is Test`

### Git Conventions
- Commit messages should be concise and descriptive
- Run `forge fmt` and `forge test` before committing
- Submodules: `lib/solady` and `lib/forge-std`

## Project Structure

```
parallel-token/
├── src/                  # Smart contract source
│   └── ParallelToken.sol
├── test/                 # Test files
│   └── ParallelToken.t.sol
├── script/               # Deployment scripts
├── lib/                  # Dependencies (solady, forge-std)
├── out/                  # Compiler output
├── cache/                # Cache files
├── foundry.toml          # Foundry configuration
└── .github/workflows/    # CI configuration
```

## Dependencies

- **solady**: Gas-optimized Solidity library (`lib/solady`)
- **forge-std**: Testing framework (`lib/forge-std`)

## Additional Notes

- This project uses a unique token ID system based on `keccak256` of sender + nonce
- The token supports push-based transfers (sender initiates) and pull-based transfers (receiver initiates)
- Operators can transfer tokens on behalf of owners
- Per-token approval system (approve for specific token IDs)
