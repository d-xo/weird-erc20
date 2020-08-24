# Weird ERC20 Tokens

The `ERC20` "specification" is so loosely defined that it amounts to little more than an interface
declaration, and even the few semantic requirements that are imposed are routinely violated by token
developers in the wild.

This makes building smart contracts that interface directly with ERC20 tokens challenging to say the
least, and smart contract developers should in general default to the following patterns when
interaction with external code is required:

1. A contract level allowlist of known good tokens.
2. Direct interaction with tokens should be performmed in dedicated wrapper contracts at the edge of
   the system. This allows the core to assume a consistent and known good semantics for the
   behaviour of external assets.

In some cases the above patterns are not practical (for example in the case of a permisionless AMM,
keeping an on chain allowlist would require the introduction of centralized control or a complex
governance system), and in these cases developers must take great care to make these interactions in
a highly defensive manner. It should be noted that even if an onchain allowlist is not feasible, an
offchain allowlist in the official UI can also protect unsophisticated users from tokens that
violate the contracts expectations, while still preserving contract level permisionlessness.

This repository contains minimal example implementations in Solidity of ERC20 tokens with behaviour
that may be surprising or unexpected. All the tokens in this repo are based on real tokens, many of
which have been used to exploit smart contract systems in the past. It is hoped that these example
implementations will be of use to developers and auditors.

Finally if you are building a token, you are strongly advised to treat the following as a list of
behaviours to avoid.

# Tokens

## Reentrant Calls

Some tokens allow reentract calls on transfer (e.g. `ERC777` tokens).

This has been exploited in the wild on multiple occasions (e.g. [imBTC uniswap pool
drained](https://defirate.com/imbtc-uniswap-hack/), [lendf.me
drained](https://defirate.com/dforce-hack/))

*example*: [Reentrant.sol](./src/Reentrant.sol)

## Missing Return Values

Some tokens do not return a bool (e.g. `BNB`, `OMG`) on ERC20 methods. see
[here](https://gist.githubusercontent.com/lukas-berlin/f587086f139df93d22987049f3d8ebd2/raw/1f937dc8eb1d6018da59881cbc633e01c0286fb0/Tokens%20missing%20return%20values%20in%20transfer) for a comprehensive (if somewhat outdated) list.

Some tokens (e.g. `BNB`) may return a `bool` for some methods, but fail to do so for others.  This
resulted in stuck `BNB` tokens in Uniswap v1
([details](https://mobile.twitter.com/UniswapProtocol/status/1072286773554876416)).

Some particulary pathological tokens (e.g. Tether Gold) declare a bool return, but then return
`false` even when the transfer was successful
([code](https://etherscan.io/address/0x4922a015c4407f87432b179bb209e125432e4a2a#code)).

The example token below returns `true` from a successful to `transfer`, but does not return anything
from a successful call to `transferFrom`.

*example*: [MissingReturns.sol](./src/MissingReturns.sol)

## Fee on Transfer

Some tokens take a transfer fee (e.g. `STA`, `PAXG`), some do not currently charge a fee but may do
so in the future (e.g. `USDT`, `USDC`).

The `STA` transfer fee was used to drain $500k from several balancer pools ([more
details](https://medium.com/@1inch.exchange/balancer-hack-2020-a8f7131c980e)).

*example*: [TransferFee.sol](./src/TransferFee.sol)

## Balance Modifications Outside of Transfers (a.k.a rebasing)

Some tokens may make arbitrary balance modifications outside of transfers (e.g. Ampleforth style rebasing tokens).

Some smart contract systems cache token balances (e.g. Balancer, Uniswap-V2), and arbitrary
modifications to underlying balances can mean that the contract is operating with outdated
information.

In the case of Uniswap-V2, the Ampleforth team ensures that `sync` is called as part of the
rebase procedure for some Uniswap pools
([details](https://www.ampltalk.org/app/forum/technology-development-17/topic/supported-dex-pools-61/)).

*example*: [Rebase.sol](./src/Rebase.sol)

## Approval Race Protections

Some tokens (e.g. `USDT`, `KNC`) do not allow approving an amount `M > 0` when an existing amount
`N > 0` is already approved. This is to protect from an ERC20 attack vector described
[here](https://docs.google.com/document/d/1YLPtQxZu1UAvO9cZ1O2RPXBbT0mooh4DYKjA_jp-RLM/edit#heading=h.b32yfk54vyg9).

[This PR](https://github.com/Uniswap/uniswap-v2-periphery/pull/26#issuecomment-647543138) shows some
in the wild problems caused by this issue.

*example*: [Approval.sol](./src/Approval.sol)

## Multiple Token Addresses

Some proxied tokens have multiple addresses. For example `TUSD` has two addresses:
`0x8dd5fbCe2F6a956C3022bA3663759011Dd51e73E` and `0x0000000000085d4780B73119b644AE5ecd22b376`
(calling transfer on either affects your balance on both).

As an example consider the following snippet. `rescueFunds` is intended to allow the contract owner
to return non pool tokens that were accidentaly sent to the contract. However, it assumes a single
address per token and so would allow the owner to steal all funds in the pool.

```solidity
mapping isPoolToken(address => bool);
constructor(address tokenA, address tokenB) public {
  isPoolToken[tokenA] = true;
  isPoolToken[tokenB] = true;
}
function rescueFunds(address token, uint amount) external nonReentrant onlyOwner {
    require(!isPoolToken[token], "Mooniswap: access denied");
    token.transfer(msg.sender, amount);
}
```

*example*: [Proxied.sol](./src/Proxied.sol)

## Low Decimals

Some tokens have low decimals (e.g. `USDC` has 6).

This may result in larger than expected precision loss.

*example*: [LowDecimals.sol](./src/LowDecimals.sol)

## High Decimals

Some tokens have more than 18 decimals (e.g. `YAM-V2` has 24).

This may trigger unexpected reverts due to overflow, posing a liveness risk to the contract.

*example*: [HighDecimals.sol](./src/HighDecimals.sol)

## Revert on Transfer to the Zero Address

Some tokens (e.g. openzeppelin) revert when attempting to transfer to `address(0)`.

This may break systems that expect to be able to burn tokens by transfering them to `address(0)`.

*example*: [RevertToZero](./src/RevertToZero.sol)
