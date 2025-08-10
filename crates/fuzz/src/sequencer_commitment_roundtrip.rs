#![no_main]

use libfuzzer_sys::fuzz_target;

use malda_utils::types::SequencerCommitment;

use malda_utils::cryptography::signature_msg;

fuzz_target!(|data: &[u8]| {

    // let _ = SequencerCommitment::new(data);
});
