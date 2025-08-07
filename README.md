# Malda Lending

Malda is a Unified Liquidity Lending protocol on Ethereum and Layer 2s,
delivering a seamless lending experience through global liquidity pools, all
secured by zkProofs.

## Security Properties

This test suite is structured to verify key security properties of the Malda
protocol at both the modular and integration levels. Properties are tested using
a combination of unit tests, invariant tests, and end-to-end integration tests.

### Gateway Module

These properties are tested in isolation on the `mTokenGateway` contract that
deployed on the Extension Chain to ensure its internal logic is sound.

| ID   | Property                                                                                               | Approach               | Result  |
| :--- | :----------------------------------------------------------------------------------------------------- | :--------------------- | :------ |
| GW01 | A user's deposit via `supplyOnHost` must be correctly and additively reflected in their `accAmountIn`. | Foundry Invariant Test | PASSED  |
| GW02 | A user can only withdraw funds via `outHere` up to the total credit proven for them (`accAmountOut`).  | Foundry Invariant Test | PASSED  |
| GW03 | All state-changing functions are properly guarded by the `notPaused` modifier.                         | Foundry Unit Test      | PENDING |
| GW04 | Access control for administrative functions (e.g., `setGasFee`) is restricted to the owner.            | Foundry Unit Test      | PENDING |

- **GW01**: Ensures that every deposit on an extension chain creates a
  verifiable credit that can later be used on the host chain. This prevents loss
  of user funds during the first step of a cross-chain supply.
- **GW02**: Guarantees that the gateway contract cannot be drained of funds.
  Withdrawals are strictly limited by the state proven from the host chain,
  preventing unauthorized fund transfers.

### Cross-Chain Interaction

These properties are verified through end-to-end integration tests that simulate
the full communication flow between the Host (`mErc20Host`) and Extension
(`mTokenGateway`) chains.

| ID   | Property                                                                                                                                  | Approach | Result  |
| :--- | :---------------------------------------------------------------------------------------------------------------------------------------- | :------- | :------ |
| CC01 | A deposit on an extension chain can be successfully claimed for mTokens on the host chain.                                                | Foundry  | PASSED  |
| CC02 | A withdrawal initiated on the host chain can be successfully claimed as underlying on the extension chain, assuming sufficient liquidity. | Foundry  | PENDING |

- **CC01:** This property proves that the credit created on the extension chain
  (G01) is not just recorded correctly but is also functional and can be used to
  mint the corresponding mTokens on the host chain, completing the cross-chain
  supply operation.
- **CC02:** This proves the reverse flow. A user who has burned mTokens on the
  host to create a credit can successfully use a ZK proof to claim their
  underlying assets on an extension chain. This test also implicitly verifies
  the dependency on the Rebalancer by checking for expected reverts when
  liquidity is insufficient.
