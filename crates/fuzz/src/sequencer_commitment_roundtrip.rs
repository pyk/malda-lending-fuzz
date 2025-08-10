#![no_main]

use alloy_primitives::{Bytes, U256};
use arbitrary::Arbitrary;
use k256::ecdsa::SigningKey;
use libfuzzer_sys::fuzz_target;
use snap::raw::Encoder;

use malda_utils::cryptography::signature_msg;
use malda_utils::types::SequencerCommitment;

// Define an arbitrary structure for the fuzzer to generate.
#[derive(Arbitrary, Debug)]
struct FuzzInput {
    // Fuzz the data payload itself.
    payload: Vec<u8>,
    // Fuzz the chain ID used in signing.
    chain_id: u64,
}

lazy_static::lazy_static! {
    static ref SIGNING_KEY: SigningKey = SigningKey::from_slice(&[42; 32]).unwrap();
}

fuzz_target!(|input: FuzzInput| {
    let sighash = signature_msg(&input.payload, input.chain_id);

    let (signature, recovery_id) = SIGNING_KEY
        .sign_prehash_recoverable(&sighash.to_vec())
        .unwrap();

    let mut sigbytes = [0u8; 65];
    sigbytes[..32].copy_from_slice(&signature.r().to_bytes());
    sigbytes[32..64].copy_from_slice(&signature.s().to_bytes());
    sigbytes[64] = recovery_id.to_byte();

    let mut decompressed = Vec::new();
    decompressed.extend_from_slice(&sigbytes);
    decompressed.extend_from_slice(&input.payload);

    let mut encoder = Encoder::new();
    let compressed = encoder.compress_vec(&decompressed).unwrap();

    if let Ok(commitment) = SequencerCommitment::new(&compressed) {
        let original_payload_bytes = Bytes::from(input.payload);
        assert_eq!(
            commitment.data, original_payload_bytes,
            "Data Mismatch: Parsed data does not match original payload!"
        );

        // Also check that the signature components are correct.
        let parsed_sig_r = U256::from_be_bytes(signature.r().to_bytes().into());
        let parsed_sig_s = U256::from_be_bytes(signature.s().to_bytes().into());

        assert_eq!(
            commitment.signature.r(),
            parsed_sig_r,
            "Signature 'r' component mismatch!"
        );
        assert_eq!(
            commitment.signature.s(),
            parsed_sig_s,
            "Signature 's' component mismatch!"
        );
    }
});
