# Attacker Can Use Fake RPC to Generate Valid Proofs

## Summary

Malicious user can provide a fake RPC during self-sequencing to generate a valid
proof for a non-existent deposit and use it to mint unbacked mTokens.

## Root Cause

The Malda Protocol provide users escape-hatch from the centralized sequencer to
do self-sequencing. Here is how the self-sequencing works:

1. User provide necessary environment variables in order to run the Malda SDK.
2. User calls `get_proof_data_prove_sdk` or `get_proof_data_prove` and sets the
   `l1_inclusion=true`.
3. User receives `journal` and `seal` to be used for the onchain transaction.

Now I can simply provide fake RPC urls via the following environment variables:

```shell
RPC_URL_ETHEREUM
```

Then this environment variable will be used by the SDK to get the state to
verify.

```rust
pub async fn get_proof_data_zkvm_input(
    users: Vec<Address>,
    markets: Vec<Address>,
    target_chain_ids: Vec<u64>,
    chain_id: u64,
    l1_inclusion: bool,
    fallback: bool,
) -> Vec<u8> {
    // Determine if the chain is a Sepolia testnet variant
    let is_sepolia = matches!(
        chain_id,
        OPTIMISM_SEPOLIA_CHAIN_ID
            | BASE_SEPOLIA_CHAIN_ID
            | ETHEREUM_SEPOLIA_CHAIN_ID
            | LINEA_SEPOLIA_CHAIN_ID
    );

    // Get the chain name and testnet status for RPC URL selection
    let (chain_name, is_testnet) = get_chain_params(chain_id);
    // @audit blindly trust rpc here
    let rpc_url = get_rpc_url(chain_name, fallback, is_testnet);
    // ...
}
```

I can configure my fake RPC to returns `getProofData` call from all or specific
gateway with specified `accAmountIn`.

For other data such as blocks, my fake RPC will returns exactly the same as the
canonical chain. You can think of the fake RPC as simple proxy that craft
specific response for the multicall requests only.

Then we got the `journal` and `seal` that we can be use to execute
`mintExternal` in the `mErc20Host` contracts.

## Internal Pre-conditions

- mErc20Host or mTokenGateway should have liquidity

## External Pre-conditions

No external pre-conditions required.

## Attack Path

I have described in the root cause section.

## Impact

Direct theft of the funds.

## PoC

N/A

## Migtigation

N/A
