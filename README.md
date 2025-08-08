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

| ID   | Property                                                                                                                                                                                                                            | Approach | Result                 |
| :--- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------- | :--------------------- |
| GW01 | A user's deposit via `supplyOnHost` must be correctly and additively reflected in their `accAmountIn`.                                                                                                                              | Foundry  | PASSED                 |
| GW02 | A user can only withdraw funds via `outHere` up to the total credit proven for them (`accAmountOut`).                                                                                                                               | Foundry  | PASSED                 |
| GW03 | Access control for administrative functions is restricted to the owner.                                                                                                                                                             | Manual   | [L01](/findings/01.md) |
| GW04 | The total amount of underlying assets held by the mTokenGateway contract must always equal the total amount supplied (accAmountIn) minus the total amount withdrawn (accAmountOut), adjusted for any funds moved by the rebalancer. | Foundry  | PENDING                |

### Cross-Chain Interaction

These properties are verified through end-to-end integration tests that simulate
the full communication flow between the Host (`mErc20Host`) and Extension
(`mTokenGateway`) chains.

| ID   | Property                                                                                                                                  | Approach | Result |
| :--- | :---------------------------------------------------------------------------------------------------------------------------------------- | :------- | :----- |
| CC01 | A deposit on an extension chain can be successfully claimed for mTokens on the host chain.                                                | Foundry  | PASSED |
| CC02 | A withdrawal initiated on the host chain can be successfully claimed as underlying on the extension chain, assuming sufficient liquidity. | Foundry  | PASSED |
