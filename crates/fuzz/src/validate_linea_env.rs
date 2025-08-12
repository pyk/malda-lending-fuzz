#![no_main]

use arbitrary::Arbitrary;
use libfuzzer_sys::fuzz_target;

use alloy_consensus::Header;
use alloy_primitives::{Address, B256, Bytes};
use k256::ecdsa::{RecoveryId, Signature, SigningKey};
use malda_utils::{constants::LINEA_CHAIN_ID, validators::validate_linea_env};
use risc0_steel::serde::RlpHeader;

#[derive(Arbitrary, Debug, Clone)]
struct ArbitraryHeaderData {
    parent_hash: [u8; 32],
    state_root: [u8; 32],
    extra_data_prefix: Vec<u8>,
}

fuzz_target!(|input: ArbitraryHeaderData| {
    let random_attacker_key =
        SigningKey::from_bytes(&B256::random().0.into()).unwrap();

    let mut header_to_sign = Header {
        extra_data: Bytes::from(input.extra_data_prefix),
        parent_hash: B256::from(input.parent_hash),
        state_root: B256::from(input.state_root),
        // The rest can be default as they are part of the hashed data.
        ommers_hash: B256::ZERO,
        beneficiary: Address::ZERO,
        transactions_root: B256::ZERO,
        receipts_root: B256::ZERO,
        logs_bloom: Default::default(),
        difficulty: Default::default(),
        number: 0,
        gas_limit: 0,
        gas_used: 0,
        timestamp: 0,
        mix_hash: B256::ZERO,
        nonce: Default::default(),
        base_fee_per_gas: None,
        withdrawals_root: None,
        blob_gas_used: None,
        excess_blob_gas: None,
        parent_beacon_block_root: None,
        requests_hash: None,
    };

    let sighash = header_to_sign.hash_slow();

    let (sig, recovery_id): (Signature, RecoveryId) = random_attacker_key
        .sign_prehash_recoverable(sighash.as_slice())
        .unwrap();

    let mut signature_bytes = [0u8; 65];
    signature_bytes[..32].copy_from_slice(&sig.r().to_bytes());
    signature_bytes[32..64].copy_from_slice(&sig.s().to_bytes());
    signature_bytes[64] = recovery_id.to_byte();

    header_to_sign.extra_data =
        [header_to_sign.extra_data.as_ref(), &signature_bytes]
            .concat()
            .into();
    let forged_header = RlpHeader::new(header_to_sign);

    if forged_header.inner().extra_data.len() < 65 {
        return;
    }

    validate_linea_env(LINEA_CHAIN_ID, &forged_header);

    panic!("A header signed by a random key passed validation!");
});
