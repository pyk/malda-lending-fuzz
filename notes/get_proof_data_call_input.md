```
=== get_linking_blocks args
=== * chain_id=1
=== * rpc_url="https://eth.merkle.io"
=== * current_block=23130178
=== get_proof_data_call_input args
=== * chain_id=1
=== * chain_url="https://eth.merkle.io"
=== * block=23130178
=== * users=[0x86b3bb942f2d4ea4a9aa9ebf2a3815e229117cb7]
=== * markets=[0xacc4644fc5877e06d8d78aaf3c913307f380020a]
=== * target_chain_ids=[1, 10, 8453, 59144]
=== * validate_l1_inclusion=false
=== * fallback=true
```

thread 'viewcalls::tests::test_get_proof_data_zkvm_input' (87038) panicked at
crates/malda_rs/src/viewcalls.rs:1539:22: Failed to convert environment to
input: eth_getProof failed
