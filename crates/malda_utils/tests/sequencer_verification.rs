use alloy_primitives::{Address, Bytes, Signature, U256};
use malda_utils::{
    constants::{
        BASE_CHAIN_ID, BASE_SEQUENCER, OPTIMISM_CHAIN_ID, OPTIMISM_SEQUENCER,
    },
    types::SequencerCommitment,
};
use serde::Deserialize;

#[derive(Deserialize, Debug)]
struct ApiResponse {
    data: String,
    signature: ApiSignature,
}

#[derive(Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
struct ApiSignature {
    r: String,
    s: String,
    y_parity: String,
}

async fn run_verification_test(
    url: &str,
    chain_id: u64,
    hardcoded_sequencer: Address,
) {
    let api_response: ApiResponse = reqwest::get(url)
        .await
        .expect(&format!("Failed to fetch data from {url}"))
        .json()
        .await
        .expect("Failed to parse JSON response");

    let data = Bytes::from(
        hex::decode(&api_response.data[2..])
            .expect("Failed to decode data hex"),
    );
    let r = U256::from_str_radix(&api_response.signature.r[2..], 16)
        .expect("Failed to parse R from hex");
    let s = U256::from_str_radix(&api_response.signature.s[2..], 16)
        .expect("Failed to parse S from hex");
    let v = api_response.signature.y_parity == "0x1";

    let signature = Signature::new(r, s, v);
    let commitment = SequencerCommitment {
        data: data,
        signature,
    };

    let result = commitment.verify(hardcoded_sequencer, chain_id);
    println!("result={result:#?}");
}

#[tokio::test]
async fn test_sequencer_op_base() {
    run_verification_test(
        "https://base.operationsolarstorm.org/latest",
        BASE_CHAIN_ID,
        BASE_SEQUENCER,
    )
    .await;

    run_verification_test(
        "https://optimism.operationsolarstorm.org/latest",
        OPTIMISM_CHAIN_ID,
        OPTIMISM_SEQUENCER,
    )
    .await;
}
