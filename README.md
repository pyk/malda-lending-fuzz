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

| ID   | Property                                                                                                                                                                                                 | Approach      | Result                |
| :--- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------ | :-------------------- |
| GW01 | A user's deposit via `supplyOnHost` must be correctly and additively reflected in their `accAmountIn`.                                                                                                   | Foundry       | PASSED                |
| GW02 | A user can only withdraw funds via `outHere` up to the total credit proven for them `accAmountOut`.                                                                                                      | Foundry       | PASSED                |
| GW03 | Access control for administrative functions is restricted to the owner.                                                                                                                                  | Manual Review | [01](/findings/01.md) |
| GW04 | The total amount of underlying assets held by the `mTokenGateway` contract must always equal the total amount supplied minus the total amount withdrawn, adjusted for any funds moved by the rebalancer. | Foundry       | PASSED                |
| GW05 | The gateway's cumulative record of a user's withdrawals must never exceed the total cumulative credit proven for them from the host chain, ensuring state integrity over time against reordering.        | Foundry       | PASSED                |
| GW06 | A specific ZK proof representing withdrawal must be atomically consumed. The gateway must prevent the same proof from being replayed to authorize multiple withdrawals.                                  | Foundry       | PASSED                |
| GW07 | Proof verification is mandatory for untrusted callers. The gateway must reject any withdrawal attempt from a regular user that is not backed by a valid ZK proof.                                        | Foundry       | PASSED                |
| GW08 | The self-sequencing path is functional. A regular user can successfully withdraw funds by providing a valid ZK proof.                                                                                    | Foundry       | PASSED                |

### Cross-Chain Interaction

These properties are verified through end-to-end integration tests that simulate
the full communication flow between the Host (`mErc20Host`) and Extension
(`mTokenGateway`) chains.

| ID   | Property                                                                                                                                  | Approach      | Result                |
| :--- | :---------------------------------------------------------------------------------------------------------------------------------------- | :------------ | :-------------------- |
| CC01 | A deposit on an extension chain can be successfully claimed for mTokens on the host chain.                                                | Foundry       | PASSED                |
| CC02 | A withdrawal initiated on the host chain can be successfully claimed as underlying on the extension chain, assuming sufficient liquidity. | Foundry       | PASSED                |
| CC03 | The `sender` field in a ZK proof's journal must be the `msg.sender` of the transaction that initiated the cross-chain action.             | Manual Review | PASSED                |
| CC04 | A ZK proof must be bound to its intended destination market or gateway, and the target contract must enforce this binding.                | Manual Review | [02](/findings/02.md) |
