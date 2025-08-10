#![no_main]

use alloy_primitives::B256;
use arbitrary::Arbitrary;
use libfuzzer_sys::fuzz_target;
use malda_utils::cryptography::signature_msg;
use std::collections::HashMap;
use std::sync::Mutex;

#[derive(Arbitrary, Debug, Clone, PartialEq, Eq, Hash)]
struct FuzzInput {
    payload: Vec<u8>,
    chain_id: u64,
}

lazy_static::lazy_static! {
    static ref SEEN_HASHES: Mutex<HashMap<B256, FuzzInput>> = Mutex::new(HashMap::new());
}

// @property ZK03
// The commitment hash must be unique for each distinct (payload, chain_id) pair,
// preventing data collision and cross-chain replay attacks.
fuzz_target!(|input: FuzzInput| {
    let hash = signature_msg(&input.payload, input.chain_id);

    let mut seen_hashes = SEEN_HASHES.lock().unwrap();

    if let Some(existing_input) = seen_hashes.get(&hash) {
        assert_eq!(
            *existing_input, input,
            "Different inputs produced the same signature hash.\\nInput 1: {:?}\\nInput 2: {:?}",
            existing_input, input
        );
    } else {
        seen_hashes.insert(hash, input);
    }
});
