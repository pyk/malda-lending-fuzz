
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
