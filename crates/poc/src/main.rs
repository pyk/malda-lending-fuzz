fn main() {}

#[cfg(test)]
mod tests {
    use alloy_consensus::Header;
    use alloy_primitives::{Address, Bytes, address};
    use malda_rs::viewcalls::get_proof_data_zkvm_input;
    use malda_utils::constants::{
        BASE_CHAIN_ID, ETHEREUM_CHAIN_ID, LINEA_CHAIN_ID,
    };
    use malda_utils::{
        types::{LINEA_MAINNET_CHAIN_SPEC, SequencerCommitment},
        validators::validate_get_proof_data_call,
    };
    use risc0_op_steel::optimism::OpEvmInput;
    use risc0_steel::{ethereum::EthEvmInput, serde::RlpHeader};
    use risc0_zkvm;
    use tokio;

    const MUSDC: Address = address!("269C36A173D881720544Fb303E681370158FF1FD");
    const MWETH: Address = address!("C7Bc6bD45Eb84D594f51cED3c5497E6812C7732f");

    type DecodedInput = (
        Option<EthEvmInput>,         // 0: env_input
        u64,                         // 1: chain_id
        Vec<Address>,                // 2: account
        Vec<Address>,                // 3: asset
        Vec<u64>,                    // 4: target_chain_ids
        Option<SequencerCommitment>, // 5: sequencer_commitment
        Option<EthEvmInput>,         // 6: env_op_input
        Vec<RlpHeader<Header>>,      // 7: linking_blocks
        Option<EthEvmInput>,         // 8: env_eth_input
        Option<OpEvmInput>,          // 9: op_evm_input
        Option<SequencerCommitment>, // 10: sequencer_commitment_opstack_2
        Option<EthEvmInput>,         // 11: env_op_input_2
    );

    fn decode_input(input: Vec<u8>) -> DecodedInput {
        let des: DecodedInput =
            risc0_zkvm::serde::from_slice(&input).expect("X");
        return des;
    }

    fn validate_decoded_input_linea(decoded_input: DecodedInput) {
        println!("=== validate_decode_input_linea");
        let env_input = decoded_input.0;
        let env_input_for_viewcall = env_input
            .expect("env_input is None")
            .into_env(&LINEA_MAINNET_CHAIN_SPEC);
        println!("=== * env_input -> env_input_for_viewcall");
        println!(
            "=== * env_input_for_viewcall block_number = {:?}",
            env_input_for_viewcall.header().number,
        );
        let chain_id = decoded_input.1;
        println!("=== * chain_id={:?}", chain_id);
        let account = decoded_input.2;
        println!("=== * account={:?}", account);
        let asset = decoded_input.3;
        println!("=== * asset={:?}", asset);
        let target_chain_ids = decoded_input.4;
        println!("=== * target_chain_ids={:?}", target_chain_ids);
        let sequencer_commitment = decoded_input.5;
        // when chain_id=linea and l1_inclusion=false, env_op_input is unused in
        // the Guest program
        // let env_op_input = decoded_input.6;

        let linking_blocks = decoded_input.7;
        println!("=== * linking_blocks={:?}", linking_blocks);
    }

    #[tokio::test]
    async fn test_linea_e2e_non_l1_inclusion() {
        let users = Vec::from([Address::random(), Address::random()]);
        let markets = Vec::from([MUSDC, MWETH]);
        let target_chain_ids = Vec::from([ETHEREUM_CHAIN_ID, LINEA_CHAIN_ID]);
        let chain_id = LINEA_CHAIN_ID;
        let l1_inclusion = false;
        let fallback = false;

        println!("=== LINEA E2E TEST ===");
        println!("=== * users={:?}", users);
        println!("=== * markets={:?}", markets);
        println!("=== * target_chain_ids={:?}", target_chain_ids);
        println!("=== * chain_id={}", chain_id);
        println!("=== * l1_inclusion={}", l1_inclusion);
        println!("=== * fallback={}", fallback);
        println!("=== get_proof_data_zkvm_input START");
        let input = get_proof_data_zkvm_input(
            users,
            markets,
            target_chain_ids,
            chain_id,
            l1_inclusion,
            fallback,
        )
        .await;
        println!("=== get_proof_data_zkvm_input END");
        println!("=== decode_input START");
        let decoded_input = decode_input(input);
        println!("=== decode_input END");
        // validate_decoded_input_linea(decoded_input);
        let chain_id = decoded_input.1;
        let account = decoded_input.2;
        let asset = decoded_input.3;
        let target_chain_ids = decoded_input.4;
        let env_input = decoded_input.0;
        let sequencer_commitment = decoded_input.5;
        let env_op_input = decoded_input.6;
        let linking_blocks = decoded_input.7;
        let mut output: Vec<Bytes> = Vec::new();
        let env_eth_input = decoded_input.8;
        let op_evm_input = decoded_input.9;
        let sequencer_commitment_opstack_2 = decoded_input.10;
        let env_op_input_2 = decoded_input.11;
        println!("=== validate_get_proof_data_call START");
        validate_get_proof_data_call(
            chain_id,
            account,
            asset,
            target_chain_ids,
            env_input,
            sequencer_commitment,
            env_op_input,
            &linking_blocks,
            &mut output,
            &env_eth_input,
            op_evm_input,
            sequencer_commitment_opstack_2,
            env_op_input_2,
        );
        println!("=== validate_get_proof_data_call END");

        println!("=== SUCCESS ===");
    }

    #[tokio::test]
    async fn test_linea_e2e_l1_inclusion() {
        let users = Vec::from([Address::random(), Address::random()]);
        let markets = Vec::from([MUSDC, MWETH]);
        let target_chain_ids =
            Vec::from([ETHEREUM_CHAIN_ID, ETHEREUM_CHAIN_ID]);
        let chain_id = LINEA_CHAIN_ID;
        let l1_inclusion = true;
        let fallback = false;

        println!("=== LINEA E2E TEST ===");
        println!("=== * users={:?}", users);
        println!("=== * markets={:?}", markets);
        println!("=== * target_chain_ids={:?}", target_chain_ids);
        println!("=== * chain_id={}", chain_id);
        println!("=== * l1_inclusion={}", l1_inclusion);
        println!("=== * fallback={}", fallback);
        println!("=== get_proof_data_zkvm_input START");
        let input = get_proof_data_zkvm_input(
            users,
            markets,
            target_chain_ids,
            chain_id,
            l1_inclusion,
            fallback,
        )
        .await;
        println!("=== get_proof_data_zkvm_input END");
        println!("=== decode_input START");
        let decoded_input = decode_input(input);
        println!("=== decode_input END");
        // validate_decoded_input_linea(decoded_input);
        let chain_id = decoded_input.1;
        let account = decoded_input.2;
        let asset = decoded_input.3;
        let target_chain_ids = decoded_input.4;
        let env_input = decoded_input.0;
        let sequencer_commitment = decoded_input.5;
        let env_op_input = decoded_input.6;
        let linking_blocks = decoded_input.7;
        let mut output: Vec<Bytes> = Vec::new();
        let env_eth_input = decoded_input.8;
        let op_evm_input = decoded_input.9;
        let sequencer_commitment_opstack_2 = decoded_input.10;
        let env_op_input_2 = decoded_input.11;
        println!("=== validate_get_proof_data_call START");
        validate_get_proof_data_call(
            chain_id,
            account,
            asset,
            target_chain_ids,
            env_input,
            sequencer_commitment,
            env_op_input,
            &linking_blocks,
            &mut output,
            &env_eth_input,
            op_evm_input,
            sequencer_commitment_opstack_2,
            env_op_input_2,
        );
        println!("=== validate_get_proof_data_call END");

        println!("=== SUCCESS ===");
    }

    #[tokio::test]
    async fn test_ethereum_e2e_non_l1_inclusion() {
        let users = Vec::from([Address::random(), Address::random()]);
        let markets = Vec::from([MUSDC, MWETH]);
        let target_chain_ids = Vec::from([LINEA_CHAIN_ID, LINEA_CHAIN_ID]);
        let chain_id = ETHEREUM_CHAIN_ID;
        let l1_inclusion = false;
        let fallback = false;

        println!("=== ETHEREUM E2E TEST ===");
        println!("=== * users={:?}", users);
        println!("=== * markets={:?}", markets);
        println!("=== * target_chain_ids={:?}", target_chain_ids);
        println!("=== * chain_id={}", chain_id);
        println!("=== * l1_inclusion={}", l1_inclusion);
        println!("=== * fallback={}", fallback);
        println!("=== get_proof_data_zkvm_input START");
        let input = get_proof_data_zkvm_input(
            users,
            markets,
            target_chain_ids,
            chain_id,
            l1_inclusion,
            fallback,
        )
        .await;
        println!("=== get_proof_data_zkvm_input END");
        println!("=== decode_input START");
        let decoded_input = decode_input(input);
        println!("=== decode_input END");
        // validate_decoded_input_linea(decoded_input);
        let chain_id = decoded_input.1;
        let account = decoded_input.2;
        let asset = decoded_input.3;
        let target_chain_ids = decoded_input.4;
        let env_input = decoded_input.0;
        let sequencer_commitment = decoded_input.5;
        let env_op_input = decoded_input.6;
        let linking_blocks = decoded_input.7;
        let mut output: Vec<Bytes> = Vec::new();
        let env_eth_input = decoded_input.8;
        let op_evm_input = decoded_input.9;
        let sequencer_commitment_opstack_2 = decoded_input.10;
        let env_op_input_2 = decoded_input.11;
        println!("=== validate_get_proof_data_call START");
        validate_get_proof_data_call(
            chain_id,
            account,
            asset,
            target_chain_ids,
            env_input,
            sequencer_commitment,
            env_op_input,
            &linking_blocks,
            &mut output,
            &env_eth_input,
            op_evm_input,
            sequencer_commitment_opstack_2,
            env_op_input_2,
        );
        println!("=== validate_get_proof_data_call END");

        println!("=== SUCCESS ===");
    }

    #[tokio::test]
    async fn test_base_e2e_non_l1_inclusion() {
        let users = Vec::from([Address::random(), Address::random()]);
        let markets = Vec::from([MUSDC, MWETH]);
        let target_chain_ids = Vec::from([LINEA_CHAIN_ID, LINEA_CHAIN_ID]);
        let chain_id = BASE_CHAIN_ID;
        let l1_inclusion = false;
        let fallback = false;

        println!("=== BASE E2E TEST ===");
        println!("=== * users={:?}", users);
        println!("=== * markets={:?}", markets);
        println!("=== * target_chain_ids={:?}", target_chain_ids);
        println!("=== * chain_id={}", chain_id);
        println!("=== * l1_inclusion={}", l1_inclusion);
        println!("=== * fallback={}", fallback);
        println!("=== get_proof_data_zkvm_input START");
        let input = get_proof_data_zkvm_input(
            users,
            markets,
            target_chain_ids,
            chain_id,
            l1_inclusion,
            fallback,
        )
        .await;
        println!("=== get_proof_data_zkvm_input END");
        println!("=== decode_input START");
        let decoded_input = decode_input(input);
        println!("=== decode_input END");
        // validate_decoded_input_linea(decoded_input);
        let chain_id = decoded_input.1;
        let account = decoded_input.2;
        let asset = decoded_input.3;
        let target_chain_ids = decoded_input.4;
        let env_input = decoded_input.0;
        let sequencer_commitment = decoded_input.5;
        let env_op_input = decoded_input.6;
        let linking_blocks = decoded_input.7;
        let mut output: Vec<Bytes> = Vec::new();
        let env_eth_input = decoded_input.8;
        let op_evm_input = decoded_input.9;
        let sequencer_commitment_opstack_2 = decoded_input.10;
        let env_op_input_2 = decoded_input.11;
        println!("=== validate_get_proof_data_call START");
        validate_get_proof_data_call(
            chain_id,
            account,
            asset,
            target_chain_ids,
            env_input,
            sequencer_commitment,
            env_op_input,
            &linking_blocks,
            &mut output,
            &env_eth_input,
            op_evm_input,
            sequencer_commitment_opstack_2,
            env_op_input_2,
        );
        println!("=== validate_get_proof_data_call END");

        println!("=== SUCCESS ===");
    }

    #[tokio::test]
    async fn test_base_e2e_l1_inclusion() {
        let users = Vec::from([Address::random(), Address::random()]);
        let markets = Vec::from([MUSDC, MWETH]);
        let target_chain_ids = Vec::from([LINEA_CHAIN_ID, LINEA_CHAIN_ID]);
        let chain_id = BASE_CHAIN_ID;
        let l1_inclusion = true;
        let fallback = false;

        println!("=== BASE E2E TEST ===");
        println!("=== * users={:?}", users);
        println!("=== * markets={:?}", markets);
        println!("=== * target_chain_ids={:?}", target_chain_ids);
        println!("=== * chain_id={}", chain_id);
        println!("=== * l1_inclusion={}", l1_inclusion);
        println!("=== * fallback={}", fallback);
        println!("=== get_proof_data_zkvm_input START");
        let input = get_proof_data_zkvm_input(
            users,
            markets,
            target_chain_ids,
            chain_id,
            l1_inclusion,
            fallback,
        )
        .await;
        println!("=== get_proof_data_zkvm_input END");
        println!("=== decode_input START");
        let decoded_input = decode_input(input);
        println!("=== decode_input END");
        // validate_decoded_input_linea(decoded_input);
        let chain_id = decoded_input.1;
        let account = decoded_input.2;
        let asset = decoded_input.3;
        let target_chain_ids = decoded_input.4;
        let env_input = decoded_input.0;
        let sequencer_commitment = decoded_input.5;
        let env_op_input = decoded_input.6;
        let linking_blocks = decoded_input.7;
        let mut output: Vec<Bytes> = Vec::new();
        let env_eth_input = decoded_input.8;
        let op_evm_input = decoded_input.9;
        let sequencer_commitment_opstack_2 = decoded_input.10;
        let env_op_input_2 = decoded_input.11;
        println!("=== validate_get_proof_data_call START");
        validate_get_proof_data_call(
            chain_id,
            account,
            asset,
            target_chain_ids,
            env_input,
            sequencer_commitment,
            env_op_input,
            &linking_blocks,
            &mut output,
            &env_eth_input,
            op_evm_input,
            sequencer_commitment_opstack_2,
            env_op_input_2,
        );
        println!("=== validate_get_proof_data_call END");

        println!("=== SUCCESS ===");
    }
}
