# ZK Coprocessor uses incorrect EthEvmEnv when chain_id=Linea and l1_inclusion=true

## Summary

A logic flaw in the
[`sort_and_verify_relevant_params`](https://github.com/sherlock-audit/2025-07-malda-pyk/blob/51c3a8231a37b622235151254a21cebbc1fa78e1/malda-zk-coprocessor/malda_utils/src/validators.rs#L179)
function that breaks the self-sequencing mechanism for any transaction
originating from the Linea that requires L1 inclusion. The function fails to use
the provided L1 Ethereum env for validation, instead proceeding with the L2
Linea env, which makes the subsequent L1 finality checks impossible and causes
the proof generation to fail.

## Root Cause

When a user performs a self-sequenced transaction from Linea and sets
`l1_inclusion=true` as required by the onchain contracts, the ZK guest program
is expected to follow a strict validation path to prove that the L2 state has
been finalized on L1.

Here is how it works:

1. The guest program receives two EVM envs from the host: `linea_env` and
   `eth_env`.
2. `sort_and_verify_relevant_params`, should recognize that this is an L1
   inclusion case.
3. The next function in the pipeline, `validate_linea_env_with_l1_inclusion`,
   takes the L1 environment prepared in the previous step.

However, in the step 2. If we look closely how the sort and verify function
implemented:

```rust
pub fn sort_and_verify_relevant_params(
     // ...
) -> (
    // ...
) {
    let validate_l1_inclusion = env_input_eth_for_l1_inclusion.is_some();

    // Determine which environment and parameters to use based on chain type and
    // inclusion requirements.
    let (
        env_for_viewcall,
        op_env_for_viewcall_with_l1_inclusion,
        op_env_commitment,
        chain_id_for_length_validation,
    ) = if (chain_id == OPTIMISM_CHAIN_ID
        || chain_id == BASE_CHAIN_ID
        || chain_id == OPTIMISM_SEPOLIA_CHAIN_ID
        || chain_id == BASE_SEPOLIA_CHAIN_ID)
        && validate_l1_inclusion
    {
        // @audit Correct logic for OP
        let env_for_viewcall = env_input_eth_for_l1_inclusion
            .as_ref()
            .expect("env_eth_input is None")
            .clone()
            .into_env(&ETH_MAINNET_CHAIN_SPEC);
        // ...
        (
            env_for_viewcall,
            Some(op_env_for_viewcall_with_l1_inclusion),
            Some(op_env_commitment),
            chain_id_for_length_validation,
        )
    } else {
        // For L1 or Linea chains, use the provided environment input.
        let chain_spec = match chain_id {
            LINEA_CHAIN_ID => &LINEA_MAINNET_CHAIN_SPEC,
            LINEA_SEPOLIA_CHAIN_ID => &LINEA_MAINNET_CHAIN_SPEC,
            _ => &ETH_MAINNET_CHAIN_SPEC,
        };

        // @audit it completely discards the provided L1 Ethereum environment.
        (
            env_input_for_viewcall
                .expect("env_input is None")
                .into_env(&chain_spec),
            None,
            None,
            chain_id,
        )
    };
    // ...
}
```

`chain_id` is `LINEA_CHAIN_ID`, execution falls into the else block. This block
takes the L2 Linea env and returns it as the primary validation env, while
completely ignoring the provided `env_input_eth_for_l1_inclusion`.

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

Add the following test in `malda_utils/src/tests.rs`:

```rust
#[tokio::test]
async fn test_sort_params_linea_l1_inclusion_bug() {
    let linea_rpc = Url::parse("https://rpc.linea.build").unwrap();
    let eth_rpc =
        Url::parse("https://ethereum-rpc.publicnode.com").unwrap();

    let mut linea_env = EthEvmEnv::builder()
        .rpc(linea_rpc)
        .chain_spec(&LINEA_MAINNET_CHAIN_SPEC)
        .build()
        .await
        .unwrap();
    let mut eth_env = EthEvmEnv::builder()
        .rpc(eth_rpc)
        .chain_spec(&ETH_MAINNET_CHAIN_SPEC)
        .build()
        .await
        .unwrap();

    let expected_header_hash = eth_env.header().seal();
    println!("Expecting L1 header hash: {}", expected_header_hash);

    println!(
        "Successfully built environment for Linea block: {}",
        linea_env.header().number
    );
    println!(
        "Successfully built environment for Ethereum block: {}",
        eth_env.header().number
    );

    Account::preflight(Address::ZERO, &mut linea_env)
        .info()
        .await
        .unwrap();
    Account::preflight(Address::ZERO, &mut eth_env)
        .info()
        .await
        .unwrap();

    let linea_input = linea_env.into_input().await.unwrap();
    let eth_input = eth_env.into_input().await.unwrap();

    let linking_blocks = Vec::<RlpHeader<Header>>::new();

    let (
        returned_env,
        _block_header_to_validate,
        _env_header_hash_to_validate,
        _env_header_to_validate,
        _op_env_for_viewcall,
        _op_env_commitment,
        _returned_chain_id_for_validation,
        returned_l1_inclusion_flag,
    ) = sort_and_verify_relevant_params(
        LINEA_CHAIN_ID,
        Some(linea_input),
        &linking_blocks,
        &Some(eth_input),
        None,
    );

    assert!(
        returned_l1_inclusion_flag,
        "l1_inclusion should be true, but was set to false"
    );
    assert_eq!(
        returned_env.header().seal(),
        expected_header_hash,
        "The returned `env_for_viewcall` should have been the L1 Ethereum environment, but it was not."
    );
}
```

Then run the test:

```shell
cargo test --package malda_utils test_sort_params_linea_l1_inclusion_bug -- --nocapture
```

Logs:

```shell
   Compiling malda_utils v0.1.0 (/home/pyk/github/malda-lending-fuzz/crates/malda_utils)
    Finished `test` profile [unoptimized + debuginfo] target(s) in 1.30s
     Running unittests src/lib.rs (target/debug/deps/malda_utils-4489f8eb330de64f)

running 1 test
Expecting L1 header hash: 0x42135aa3e972c86e640fb8d88ee8019be57665915f5b12367c2baefc42a2bda2
Successfully built environment for Linea block: 21923262
Successfully built environment for Ethereum block: 23121488

thread 'validators::tests::test_sort_params_linea_l1_inclusion_bug' (187489) panicked at crates/malda_utils/src/validators.rs:1306:9:
assertion `left == right` failed: BUG: The returned `env_for_viewcall` should have been the L1 Ethereum environment, but it was not.
  left: 0x544286d38fee6c4c00f07156fbde3c28ca512ea72613673b983cf25cfec403df
 right: 0x42135aa3e972c86e640fb8d88ee8019be57665915f5b12367c2baefc42a2bda2
note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace
test validators::tests::test_sort_params_linea_l1_inclusion_bug ... FAILED

failures:

failures:
    validators::tests::test_sort_params_linea_l1_inclusion_bug

test result: FAILED. 0 passed; 1 failed; 0 ignored; 0 measured; 9 filtered out; finished in 1.97s

error: test failed, to rerun pass `-p malda_utils --lib`
```
