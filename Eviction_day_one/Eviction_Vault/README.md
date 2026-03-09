## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

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

# Eviction Vault

**EvictionVault** is a secure, gas-efficient smart contract system for managing token claims, vesting, or eviction-based distributions using **Merkle trees** for scalability and **ECDSA signatures** for authorization. Built with Foundry, OpenZeppelin, and modern Solidity best practices.

Ideal for:
- Token airdrops / retroactive rewards
- Allowlist / whitelist claims
- Vesting or eviction vaults with claim verification
- Gasless claim patterns (via signatures + relayers)

## Features

- **Merkle-proof-based claims** — extremely gas-efficient for large user sets
- **ECDSA signature verification** — supports signed authorizations (e.g. gasless claims)
- **Pausable** — emergency pause functionality
- **Multisig governance** support (via `Multisig.sol`)
- **Balance & claim tracking** — prevents double-claims
- **Safe token transfers** — using OpenZeppelin `SafeERC20`
- Fully tested with Foundry
- Modular design (`Claimable`, `BalanceManager`, `EvictionVault`, etc.)

## Tech Stack

- Solidity ^0.8.33
- [Foundry](https://getfoundry.sh/) – development, testing & deployment
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/5.x/) – `MerkleProof`, `ECDSA`, `Pausable`, `SafeERC20`, etc.

## Project Structure
