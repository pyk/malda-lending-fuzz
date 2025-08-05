# Malda Lending

Malda is a Unified Liquidity Lending protocol on Ethereum and Layer 2s,
delivering a seamless lending experience through global liquidity pools, all
secured by zkProofs.

## Security Properties

| Contract | Property | Approach               | Result |
| -------- | -------- | ---------------------- | ------ |
| Gateway  | `G01`    | Foundry Invariant Test | PASSED |
| Gateway  | `G02`    | Foundry Invariant Test | PASSED |

- `G01`: A user's deposit on an extension chain must be reflected as an increase
  in `accAmountIn`, making it claimable on the host chain.
- `G02`: Funds can only be withdrawn from the gateway if a corresponding credit
  (`accAmountOut`) has been proven from the host chain.
