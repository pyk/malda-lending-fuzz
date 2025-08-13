# get_l1block_call_input Uses Incorrect ChainSpec

## Summary

`get_l1block_call_input` is used to retrieves L1 block information for L2
chains. It queries the `L1Block` contract on L2 chains to get L1 block
information. However, it incorrectly use `ETH_MAINNET_CHAIN_SPEC` causing the
proof generation to fails.

## Root Cause

The root cause is in the following function:

```rust
pub async fn get_l1block_call_input(
    block: BlockNumberOrTag,
    chain_id: u64,
    fallback: bool,
) -> (EvmInput<EthEvmFactory>, u64) {
    let (chain_name, is_testnet) = get_chain_params(chain_id);
    let rpc_url = get_rpc_url(chain_name, fallback, is_testnet);
    let mut env = EthEvmEnv::builder()
        .rpc(Url::parse(rpc_url).expect("Failed to parse RPC URL"))
        .block_number_or_tag(block)
        .chain_spec(&ETH_MAINNET_CHAIN_SPEC) // @audit always fails
        .build()
        .await
        .expect("Failed to build EVM environment");

    // ...
}
```

I have provided test case on the PoC section below on how both centralized
sequencer (`l1_inclusion=false`) and self-sequencing (`l1_inclusion=true`) will
always failed.

## Internal Pre-conditions

No internal pre-conditions are required.

## External Pre-conditions

No external pre-conditions are required.

## Attack Path

This is not an attack.

## Impact

It completely breaks a core self-sequencing feature described in the
architecture.

## PoC

Add the following test to `malda_rs/tests/tests.rs`:

```rust
#[tokio::test]
#[should_panic(
    expected = "Failed to build EVM environment: computed block hash does not match the hash returned by the API"
)]
async fn test_incorrect_chain_spec() {
    let chain_id = OPTIMISM_CHAIN_ID;
    let l1_inclusion = true;

    let users = vec![USER];
    let markets = vec![WETH_MARKET_SEPOLIA];
    let target_chain_ids = vec![LINEA_CHAIN_ID];
    let fallback = false;

    get_proof_data_zkvm_input(
        users,
        markets,
        target_chain_ids,
        chain_id,
        l1_inclusion,
        fallback,
    )
    .await;
}
```

Use the following environment variables:

```shell
RPC_URL_ETHEREUM=https://eth.merkle.io
SEQUENCER_REQUEST_OPTIMISM=https://optimism.operationsolarstorm.org/latest
RPC_URL_OPTIMISM=https://optimism.gateway.tenderly.co
```

Then run the test:

```shell
cargo test --package malda_rs --test tests test_incorrect_chainspec
```

Logs:

```shell
warning: unused import: `sol_types::SolValue`
  --> crates/malda_rs/src/viewcalls.rs:86:47
   |
86 | use alloy::{signers::local::PrivateKeySigner, sol_types::SolValue};
   |                                               ^^^^^^^^^^^^^^^^^^^
   |
   = note: `#[warn(unused_imports)]` on by default

warning: `malda_rs` (lib) generated 1 warning (run `cargo fix --lib -p malda_rs` to apply 1 suggestion)
    Finished `test` profile [unoptimized + debuginfo] target(s) in 0.34s
     Running tests/tests.rs (target/debug/deps/tests-e748a5907664f80a)

running 1 test
test tests::test_incorrect_chain_spec - should panic ... ok

test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 13 filtered out; finished in 2.61s
```
