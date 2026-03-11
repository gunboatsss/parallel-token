## ParallelToken

A reimagine of fungible token API. This took inspriation from ERC-6909 and Sui's `Coin`.

### Thesis

L2 is going to need to specialized than just running EVM. They will do parallelized EVM (seen in Polygon, Monad, Sei and soon Rise chain) and reprice the gas to incenitvize parallel execution. This implementation try to make it non-blocking by making UTXO-style coin. If those did not come to happen then it's ERC-20 but with memo transfer.

#### No callback

This design took the learning from ERC-721 and ERC-1155 that callback on EVM SUCKS. In the year of lord 2026, you should be using wei-roll or have wallet that support ERC-6357 by any mean. And if any wallet software implementation doesn't support it, we should shame them! (looking at you, Trezor). As an vibe-coded example, there is Uniswap V2 implementation that use ParallelToken implementation instead of ERC-20.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
