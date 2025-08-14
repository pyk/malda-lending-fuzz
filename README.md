# Malda Lending Protocol Fuzzing Campaign

Malda is a Unified Liquidity Lending protocol on Ethereum and Layer 2s,
delivering a seamless lending experience through global liquidity pools, all
secured by zkProofs.

## Requirements

Nightly version of foundry:

```shell
$forge --version

forge Version: 1.3.0-v1.3.0-rc4
Commit SHA: b918f9b4ab0616b44e660a6bf8c5a47feece6505
Build Timestamp: 2025-07-30T09:05:01.422887473Z (1753866301)
Build Profile: maxperf
```

Cargo fuzz:

```shell
$ cargo --version
cargo 1.91.0-nightly (840b83a10 2025-07-30)

$ cargo fuzz --version
cargo-fuzz 0.13.1
```

## Setup

Install dependencies:

```shell
cd contracts && forge install
cargo build
```

## Security Properties

This test suite is structured to verify key security properties of the Malda
protocol at both the modular and integration levels. Properties are tested using
a combination of unit tests, invariant tests, and end-to-end integration tests.

### Gateway Module

These properties are tested in isolation on the `mTokenGateway` contract that
deployed on the Extension Chain to ensure its internal logic is sound.

| ID   | Property                                                                                                                                               | Approach      | Result                |
| :--- | :----------------------------------------------------------------------------------------------------------------------------------------------------- | :------------ | :-------------------- |
| GW01 | A user's deposit via `supplyOnHost` must be added to their `accAmountIn` balance.                                                                      | Foundry       | PASSED                |
| GW02 | A user must not be able to withdraw funds via `outHere` exceeding their proven `accAmountOut`.                                                         | Foundry       | PASSED                |
| GW03 | Administrative functions must only be callable by the contract owner.                                                                                  | Manual Review | [01](/findings/01.md) |
| GW04 | The total underlying assets held by `mTokenGateway` must always equal the total supplied minus the total withdrawn, adjusted for rebalancer movements. | Foundry       | PASSED                |
| GW05 | A user's cumulative recorded withdrawals must not exceed their total proven credit from the host chain.                                                | Foundry       | PASSED                |
| GW06 | A ZK proof for a withdrawal must be consumed upon use and must not be replayable.                                                                      | Foundry       | PASSED                |
| GW07 | Withdrawals from non-privileged users must be accompanied by a valid ZK proof.                                                                         | Foundry       | PASSED                |
| GW08 | A user with a valid ZK proof must be able to successfully withdraw funds.                                                                              | Foundry       | PASSED                |

### Cross-Chain Interaction

These properties are verified through end-to-end integration tests that simulate
the full communication flow between the Host (`mErc20Host`) and Extension
(`mTokenGateway`) chains.

| ID   | Property                                                                                                                      | Approach      | Result                |
| :--- | :---------------------------------------------------------------------------------------------------------------------------- | :------------ | :-------------------- |
| CC01 | A deposit on an extension chain must be claimable for mTokens on the host chain.                                              | Foundry       | PASSED                |
| CC02 | A withdrawal from the host chain must be claimable on the extension chain, provided there is sufficient liquidity.            | Foundry       | PASSED                |
| CC03 | The `sender` field in a ZK proof's journal must be the `msg.sender` of the transaction that initiated the cross-chain action. | Manual Review | PASSED                |
| CC04 | The target contract must enforce that a ZK proof is bound to its intended destination market or gateway.                      | Manual Review | PASSED                |
| CC05 | There must be a trustless mechanism for users to reclaim funds if the off-chain sequencer fails to generate a proof.          | Manual Review | [03](/findings/03.md) |

### ZK Coprocessor

These properties ensure the integrity and correctness of the off-chain ZK proof
generation process. They focus on preventing vulnerabilities within the guest
program and the host logic that prepares its inputs.

| ID   | Property                                                                                                                                                            | Approach           | Result                |
| :--- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------ | :----------------- | :-------------------- |
| ZK01 | The ZK Coprocessor must be compatible with the specifications of every chain on which the protocol is deployed.                                                     | Manual Review      | [03](/findings/03.md) |
| ZK02 | Serializing and deserializing a sequencer commitment must be a lossless process.                                                                                    | Cargo Fuzz         | PASSED                |
| ZK03 | The commitment hashing scheme must enforce domain separation.                                                                                                       | Cargo Test         | PASSED                |
| ZK04 | The commitment hash must be unique for each distinct `(payload, chain_id)` pair.                                                                                    | Cargo Fuzz         | PASSED                |
| ZK05 | The custom ABI encoding for journal data must prevent silent integer truncation.                                                                                    | Cargo Test         | PASSED                |
| ZK06 | The ZK Coprocessor must not generate a valid proof for a state that never existed on the source chain.                                                              | Manual Review      | PASSED                |
| ZK07 | The ZK Coprocessor must use up-to-date network parameters.                                                                                                          | Cargo Test         | PASSED                |
| ZK08 | The ZK Coprocessor must not consider a dispute game's resolution final until the entire delay period has passed.                                                    | Manual Review      | [06](/findings/06.md) |
| ZK09 | The self-sequencing mechanism must correctly process transactions from Ethereum, including proper handling of the `l1_inclusion` flag.                              | Cargo Test         | [07](/findings/07.md) |
| ZK10 | The ZK Coprocessor must use the correct chain specification for the L2 it is validating.                                                                            | Cargo Test         | PASSED                |
| ZK11 | The self-sequencing mechanism for Linea transactions must operate only on L2 state that is finalized on Ethereum L1.                                                | Cargo Test         | PASSED                |
| ZK12 | The ZK Coprocessor must verify that any Linea block header used in a `l1_inclusion=false` proof is signed by the canonical Linea sequencer.                         | Manual Review      | PASSED                |
| ZK13 | The ZK Coprocessor must ensure that a verified Linea block header is the tip of a chain of at least `REORG_PROTECTION_DEPTH_LINEA` blocks.                          | Manual Review      | PASSED                |
| ZK14 | The format of the journal entry generated by the ZK Coprocessor must exactly match the decoding logic of the on-chain `mTokenProofDecoderLib`.                      | Manual Review      | PASSED                |
| ZK15 | The ZK Coprocessor must correctly process batched proof requests, generating a unique journal entry for each corresponding `(user, market, target_chain_id)` tuple. | [Cargo Test][ZK15] | PASSED                |

[ZK15]:
  https://github.com/pyk/malda-lending-fuzz/blob/cc4ee3068190b489f8a72238ad666f6425a75ea3/crates/poc/src/main.rs#L136

## Tests

Run the invariant tests of the smart contract using the following command:

```shell
cd contracts && just fuzz
```

Use the following command to run the test and fuzzing campaign of the ZK
Coprocessor:

```shell
cargo test --package malda_rs
cargo test --package malda_utils
cargo fuzz run --fuzz-dir crates/fuzz [target]
```
