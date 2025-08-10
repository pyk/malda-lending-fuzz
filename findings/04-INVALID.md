# Sequencer Commitment Verification Always Fails

The ZK Coprocessor fails to validate sequencer commitments from Helios instances
because it uses incorrect, outdated sequencer addresses for Optimism and Base.

## Root Cause

The sequencer addresses are defined in the
[malda_utils/src/constants.rs](https://github.com/sherlock-audit/2025-07-malda-pyk/blob/51c3a8231a37b622235151254a21cebbc1fa78e1/malda-zk-coprocessor/malda_utils/src/constants.rs#L45-L47):

```rust
/// The address of the Optimism sequencer contract.
pub const OPTIMISM_SEQUENCER: Address = address!("AAAA45d9549EDA09E70937013520214382Ffc4A2");
/// The address of the Base sequencer contract.
pub const BASE_SEQUENCER: Address = address!("Af6E19BE0F9cE7f8afd49a1824851023A8249e8a");
```

Theses addresses exactly mirror the
[Helios](https://github.com/a16z/helios/blob/a0e50e11066f999c393f58271cb255ace2a6c179/opstack/src/config.rs#L85C13-L110C15)
configuration:

```rust
// opstack/src/config.rs
Network::OpMainnet => NetworkConfig {
    consensus_rpc: Some(
        "https://op-mainnet.operationsolarstorm.org"
            .parse()
            .unwrap(),
    ),
    chain: ChainConfig {
        chain_id: 10,
        unsafe_signer: address!("AAAA45d9549EDA09E70937013520214382Ffc4A2"),
        system_config_contract: address!("229047fed2591dbec1eF1118d64F7aF3dB9EB290"),
        eth_network: EthNetwork::Mainnet,
        forks: SuperchainForkSchedule::mainnet(),
    },
    verify_unsafe_signer: false,
},
Network::Base => NetworkConfig {
    consensus_rpc: Some("https://base.operationsolarstorm.org".parse().unwrap()),
    chain: ChainConfig {
        chain_id: 8453,
        unsafe_signer: address!("Af6E19BE0F9cE7f8afd49a1824851023A8249e8a"),
        system_config_contract: address!("73a79Fab69143498Ed3712e519A88a918e1f4072"),
        eth_network: EthNetwork::Mainnet,
        forks: SuperchainForkSchedule::mainnet(),
    },
    verify_unsafe_signer: false,
},
```

While Helios uses these addresses as a fallback, it also has a feature to fetch
the current sequencer address from the L1 chain and update it. OP Stack chains
can and do update their sequencer addresses over time.

The ZK Coprocessor's `validate_opstack_env` function uses these hardcoded
addresses for verification:

```rust
// malda-zk-coprocessor/malda_utils/src/validators.rs
pub fn validate_opstack_env(chain_id: u64, commitment: &SequencerCommitment, env_block_hash: B256) {
    // Verify the sequencer commitment for the correct chain and sequencer address.
    match chain_id {
        OPTIMISM_CHAIN_ID => commitment
            .verify(OPTIMISM_SEQUENCER, OPTIMISM_CHAIN_ID)
            .expect("Failed to verify Optimism sequencer commitment"),
        BASE_CHAIN_ID => commitment
            .verify(BASE_SEQUENCER, BASE_CHAIN_ID)
            .expect("Failed to verify Base sequencer commitment"),
        OPTIMISM_SEPOLIA_CHAIN_ID => commitment
            .verify(OPTIMISM_SEPOLIA_SEQUENCER, OPTIMISM_SEPOLIA_CHAIN_ID)
            .expect("Failed to verify Optimism Sepolia sequencer commitment"),
        BASE_SEPOLIA_CHAIN_ID => commitment
            .verify(BASE_SEPOLIA_SEQUENCER, BASE_SEPOLIA_CHAIN_ID)
            .expect("Failed to verify Base Sepolia sequencer commitment"),
        _ => panic!("invalid chain id"),
    }
    // Convert the commitment to an execution payload and check the block hash.
    let payload = ExecutionPayload::try_from(commitment)
        .expect("Failed to convert sequencer commitment to execution payload");
    assert_eq!(payload.block_hash, env_block_hash, "block hash mismatch");
}
```

Since live Helios instances use the current, updated sequencer addresses, the
signatures they produce will not match the outdated addresses hardcoded in the
ZK Coprocessor. This causes the verify function to fail every time.

## Internal Pre-conditions

No internal pre-conditions are required.

## External Pre-conditions

- Helios `verify_unsafe_signer` is enabled

## Impact

The ZK Coprocessor will always fail to validate sequencer commitments from live
Optimism and Base networks, making it unable to process their data.

## PoC

The following Python script proves that the sequencer addresses are incorrect.
It fetches the latest commitment from live Helios instances and shows that the
signer's address does not match the hardcoded constants.

```python
import requests
from eth_account import Account
from eth_utils import keccak, to_bytes, to_checksum_address

# NOTE: this is from zk coprocessor source code
CHAIN_CONFIGS = {
    "base": {
        "chain_id": 8453,
        "sequencer_address": "0xAf6E19BE0F9cE7f8afd49a1824851023A8249e8a",
        "url": "https://base.operationsolarstorm.org/latest"
    },
    "optimism": {
        "chain_id": 10,
        "sequencer_address": "0xAAAA45d9549EDA09E70937013520214382Ffc4A2",
        "url": "https://optimism.operationsolarstorm.org/latest"
    }
}

def create_signature_msg(data_hex: str, chain_id: int) -> bytes:
    """
    Recreates the message hash exactly as the Malda Rust code does.
    This is a hash over: (domain_separator || chain_id || keccak256(data))
    """
    domain = b'\\x00' * 32
    chain_id_bytes = chain_id.to_bytes(32, 'big')
    # NOTE: The `data` from the API is already compressed and ready for hashing.
    payload_hash = keccak(hexstr=data_hex)

    signing_data = domain + chain_id_bytes + payload_hash
    return keccak(signing_data)

def verify_chain(chain_name: str, config: dict):
    """
    Fetches the latest commitment for a chain and verifies its signature.
    """
    print(f"/// Verifying {chain_name.upper()}")
    print("////////////////////////////////////////////////////////////////")

    try:
        response = requests.get(config["url"])
        response.raise_for_status()
        commitment = response.json()
        print(f"Successfully fetched commitment from {config['url']}")
    except requests.exceptions.RequestException as e:
        print(f"❌ ERROR: Could not fetch data from {config['url']}. Error: {e}")
        return

    data_hex = commitment.get("data")
    signature_obj = commitment.get("signature")

    if not data_hex or not signature_obj:
        print("❌ ERROR: Invalid JSON response from API. Missing 'data' or 'signature'.")
        return

    sig_r = signature_obj.get("r")
    sig_s = signature_obj.get("s")
    y_parity = signature_obj.get("yParity")

    if not all([sig_r, sig_s, y_parity is not None]):
        print("❌ ERROR: Invalid signature object in JSON response.")
        return

    message_hash = create_signature_msg(data_hex, config["chain_id"])

    v = 27 + int(y_parity, 16)

    try:
        recovered_address = Account._recover_hash(
            message_hash,
            vrs=(v, to_bytes(hexstr=sig_r), to_bytes(hexstr=sig_s))
        )
    except Exception as e:
        print(f"❌ ERROR: Cryptographic recovery failed. Error: {e}")
        return

    expected_address_checksum = to_checksum_address(config["sequencer_address"])
    recovered_address_checksum = to_checksum_address(recovered_address)

    print(f"Hardcoded Sequencer Address: {expected_address_checksum}")
    print(f"Recovered Signer Address:    {recovered_address_checksum}")

    if recovered_address_checksum == expected_address_checksum:
        print("✅ SUCCESS: The recovered address matches the hardcoded constant.\\n")
    else:
        print("❌ FAILURE: The recovered address does NOT match the hardcoded constant.\\n")


if __name__ == "__main__":
    for chain_name, config in CHAIN_CONFIGS.items():
        verify_chain(chain_name, config)
```

Install dependencies:

```shell
uv add requests eth-account eth-utils
```

Run the script:

```
uv run verify_sequencer_address.py
```

Example logs:

```
/// Verifying BASE
////////////////////////////////////////////////////////////////
Successfully fetched commitment from https://base.operationsolarstorm.org/latest
Hardcoded Sequencer Address: 0xAf6E19BE0F9cE7f8afd49a1824851023A8249e8a
Recovered Signer Address:    0x503e7553062397CD7C12a3954349ae758844205f
❌ FAILURE: The recovered address does NOT match the hardcoded constant.\n
/// Verifying OPTIMISM
////////////////////////////////////////////////////////////////
Successfully fetched commitment from https://optimism.operationsolarstorm.org/latest
Hardcoded Sequencer Address: 0xAAAA45d9549EDA09E70937013520214382Ffc4A2
Recovered Signer Address:    0x21556F78307BA4073a440003bb5dCE00b61242d0
❌ FAILURE: The recovered address does NOT match the hardcoded constant.\n
```
