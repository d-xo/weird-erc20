# Weird ERC20 Tokens

This repository contains minimal example implementations in Solidity of ERC20 tokens with behaviour
that may be surprising or unexpected. All the tokens in this repo are based on real tokens, many of
which have been used to exploit smart contract systems in the past. It is hoped that these example
implementations will be of use to developers and auditors.

The `ERC20` "specification" is so loosely defined that it amounts to little more than an interface
declaration, and even the few semantic requirements that are imposed are routinely violated by token
developers in the wild.

This makes building smart contracts that interface directly with ERC20 tokens challenging to say the
least, and smart contract developers should in general default to the following patterns when
interaction with external code is required:

1. A contract level allowlist of known good tokens.
2. Direct interaction with tokens should be performed in dedicated wrapper contracts at the edge of
   the system. This allows the core to assume a consistent and known good semantics for the
   behaviour of external assets.

In some cases the above patterns are not practical (for example in the case of a permissionless AMM,
keeping an on chain allowlist would require the introduction of centralized control or a complex
governance system), and in these cases developers must take great care to make these interactions in
a highly defensive manner. It should be noted that even if an onchain allowlist is not feasible, an
offchain allowlist in the official UI can also protect unsophisticated users from tokens that
violate the contracts expectations, while still preserving contract level permissionlessness.

Finally if you are building a token, you are strongly advised to treat the following as a list of
behaviours to avoid.

*Additional Resources*

- Trail of Bits [token integration checklist](https://github.com/crytic/building-secure-contracts/blob/master/development-guidelines/token_integration.md).
- Consensys Diligence [token integration checklist](https://consensys.net/diligence/blog/2020/11/token-interaction-checklist/)

# Tokens

## Reentrant Calls

Some tokens allow reentrant calls on transfer (e.g. `ERC777` tokens).

This has been exploited in the wild on multiple occasions (e.g. [imBTC Uniswap pool
drained](https://defirate.com/imbtc-uniswap-hack/), [lendf.me
drained](https://defirate.com/dforce-hack/))

*example*: [Reentrant.sol](./src/Reentrant.sol)

## Missing Return Values

Some tokens do not return a bool (e.g. `USDT`, `BNB`, `OMG`) on ERC20 methods. see
[here](https://gist.githubusercontent.com/lukas-berlin/f587086f139df93d22987049f3d8ebd2/raw/1f937dc8eb1d6018da59881cbc633e01c0286fb0/Tokens%20missing%20return%20values%20in%20transfer) for a comprehensive (if somewhat outdated) list.

Some tokens (e.g. `BNB`) may return a `bool` for some methods, but fail to do so for others.  This
resulted in stuck `BNB` tokens in Uniswap v1
([details](https://mobile.twitter.com/UniswapProtocol/status/1072286773554876416)).

Some particularly pathological tokens (e.g. Tether Gold) declare a bool return, but then return
`false` even when the transfer was successful
([code](https://etherscan.io/address/0x4922a015c4407f87432b179bb209e125432e4a2a#code)).

A good safe transfer abstraction
([example](https://github.com/Uniswap/uniswap-v2-core/blob/4dd59067c76dea4a0e8e4bfdda41877a6b16dedc/contracts/UniswapV2Pair.sol#L44))
can help somewhat, but note that the existence of Tether Gold makes it impossible to correctly handle
return values for all tokens.

Two example tokens are provided:

- `MissingReturns`: does not return a bool for any erc20 operation
- `ReturnsFalse`: declares a bool return, but then returns false for every erc20 operation

*example*: [MissingReturns.sol](./src/MissingReturns.sol)  
*example*: [ReturnsFalse.sol](./src/ReturnsFalse.sol)

## Fee on Transfer

Some tokens take a transfer fee (e.g. `STA`, `PAXG`), some do not currently charge a fee but may do
so in the future (e.g. `USDT`, `USDC`).

The `STA` transfer fee was used to drain $500k from several balancer pools ([more
details](https://medium.com/@1inch.exchange/balancer-hack-2020-a8f7131c980e)).

*example*: [TransferFee.sol](./src/TransferFee.sol)

## Balance Modifications Outside of Transfers (rebasing/airdrops)

Some tokens may make arbitrary balance modifications outside of transfers (e.g. Ampleforth style
rebasing tokens, Compound style airdrops of governance tokens, mintable/burnable tokens).

Some smart contract systems cache token balances (e.g. Balancer, Uniswap-V2), and arbitrary
modifications to underlying balances can mean that the contract is operating with outdated
information.

In the case of Ampleforth, some Balancer and Uniswap pools are special cased to ensure that the
pool's cached balances are atomically updated as part of the rebase procedure
([details](https://www.ampltalk.org/app/forum/technology-development-17/topic/supported-dex-pools-61/)).

*example*: TODO: implement a rebasing token

## Upgradable Tokens

Some tokens (e.g. `USDC`, `USDT`) are upgradable, allowing the token owners to make arbitrary
modifications to the logic of the token at any point in time.

A change to the token semantics can break any smart contract that depends on the past behaviour.

Developers integrating with upgradable tokens should consider introducing logic that will freeze
interactions with the token in question if an upgrade is detected. (e.g. the [`TUSD`
adapter](https://github.com/makerdao/dss-deploy/blob/7394f6555daf5747686a1b29b2f46c6b2c64b061/src/join.sol#L321)
used by MakerDAO).

*example*: [Upgradable.sol](./src/Upgradable.sol)

## Flash Mintable Tokens

Some tokens (e.g. `DAI`) allow for so called "flash minting", which allows tokens to be minted for the duration
of one transaction only, provided they are returned to the token contract by the end of the
transaction.

This is similar to a flash loan, but does not require the tokens that are to be lent to exist before
the start of the transaction. A token that can be flash minted could potentially have a total supply
of max `uint256`.

Documentation for the MakerDAO flash mint module can be found
[here](https://docs.makerdao.com/smart-contract-modules/flash-mint-module).

## Tokens with Blocklists

Some tokens (e.g. `USDC`, `USDT`) have a contract level admin controlled address blocklist. If an
address is blocked, then transfers to and from that address are forbidden.

Malicious or compromised token owners can trap funds in a contract by adding the contract address to
the blocklist. This could potentially be the result of regulatory action against the contract
itself, against a single user of the contract (e.g. a Uniswap LP), or could also be a part of an
extortion attempt against users of the blocked contract.

*example*: [BlockList.sol](./src/BlockList.sol)

## Pausable Tokens

Some tokens can be paused by an admin (e.g. `BNB`, `ZIL`).

Similary to the blocklist issue above, an admin controlled pause feature opens users
of the token to risk from a malicious or compromised token owner.

*example*: [Pausable.sol](./src/Pausable.sol)

## Approval Race Protections

Some tokens (e.g. `USDT`, `KNC`) do not allow approving an amount `M > 0` when an existing amount
`N > 0` is already approved. This is to protect from an ERC20 attack vector described
[here](https://docs.google.com/document/d/1YLPtQxZu1UAvO9cZ1O2RPXBbT0mooh4DYKjA_jp-RLM/edit#heading=h.b32yfk54vyg9).

[This PR](https://github.com/Uniswap/uniswap-v2-periphery/pull/26#issuecomment-647543138) shows some
in the wild problems caused by this issue.

*example*: [Approval.sol](./src/Approval.sol)

## Revert on Approval To Zero Address

Some tokens (e.g. OpenZeppelin) will revert if trying to approve the zero address to spend tokens
(i.e. a call to `approve(address(0), amt)`).

Integrators may need to add special cases to handle this logic if working with such a token.

*example*: [ApprovalToZeroAddress.sol](./src/ApprovalToZeroAddress.sol)

## Revert on Zero Value Approvals

Some tokens (e.g. `BNB`) revert when approving a zero value amount (i.e. a call to `approve(address, 0)`).

Integrators may need to add special cases to handle this logic if working with such a token.

*example*: [ApprovalWithZeroValue.sol](./src/ApprovalWithZeroValue.sol)

## Revert on Zero Value Transfers

Some tokens (e.g. `LEND`) revert when transferring a zero value amount.

*example*: [RevertZero.sol](./src/RevertZero.sol)

## Multiple Token Addresses

Some proxied tokens have multiple addresses. 
As an example consider the following snippet. `rescueFunds` is intended to allow the contract owner
to return non pool tokens that were accidentally sent to the contract. However, it assumes a single
address per token and so would allow the owner to steal all funds in the pool.

```solidity
mapping isPoolToken(address => bool);
constructor(address tokenA, address tokenB) public {
  isPoolToken[tokenA] = true;
  isPoolToken[tokenB] = true;
}
function rescueFunds(address token, uint amount) external nonReentrant onlyOwner {
    require(!isPoolToken[token], "access denied");
    token.transfer(msg.sender, amount);
}
```

*example*: [Proxied.sol](./src/Proxied.sol)

## Low Decimals

Some tokens have low decimals (e.g. `USDC` has 6). Even more extreme, some tokens like [Gemini USD](https://etherscan.io/token/0x056Fd409E1d7A124BD7017459dFEa2F387b6d5Cd?a=0x5f65f7b609678448494De4C87521CdF6cEf1e932) only have 2 decimals.

This may result in larger than expected precision loss.

*example*: [LowDecimals.sol](./src/LowDecimals.sol)

## High Decimals

Some tokens have more than 18 decimals (e.g. `YAM-V2` has 24).

This may trigger unexpected reverts due to overflow, posing a liveness risk to the contract.

*example*: [HighDecimals.sol](./src/HighDecimals.sol)

## `transferFrom` with `src == msg.sender`

Some token implementations (e.g. `DSToken`) will not attempt to decrease the caller's allowance if
the sender is the same as the caller. This gives `transferFrom` the same semantics as `transfer` in
this case. Other implementations (e.g. OpenZeppelin, Uniswap-v2) will attempt to decrease the
caller's allowance from the sender in `transferFrom` even if the caller and the sender are the same
address, giving `transfer(dst, amt)` and `transferFrom(address(this), dst, amt)` a different
semantics in this case.

*examples*:

Examples of both semantics are provided:

- [ERC20.sol](./src/ERC20.sol): does not attempt to decrease allowance
- [TransferFromSelf.sol](./src/TransferFromSelf.sol): always attempts to decrease the allowance

## Non `string` metadata

Some tokens (e.g.
[`MKR`](https://etherscan.io/address/0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2#code)) have metadata
fields (`name` / `symbol`) encoded as `bytes32` instead of the `string` prescribed by the ERC20
specification.

This may cause issues when trying to consume metadata from these tokens.

*example*: [Bytes32Metadata.sol](./src/Bytes32Metadata.sol)

## Revert on Transfer to the Zero Address

Some tokens (e.g. openzeppelin) revert when attempting to transfer to `address(0)`.

This may break systems that expect to be able to burn tokens by transferring them to `address(0)`.

*example*: [RevertToZero.sol](./src/RevertToZero.sol)

## No Revert on Failure

Some tokens do not revert on failure, but instead return `false` (e.g.
[ZRX](https://etherscan.io/address/0xe41d2489571d322189246dafa5ebde1f4699f498#code), [EURS](https://etherscan.io/token/0xdb25f211ab05b1c97d595516f45794528a807ad8#code)).

While this is technically compliant with the ERC20 standard, it goes against common solidity coding
practices and may be overlooked by developers who forget to wrap their calls to `transfer` in a
`require`.

*example*: [NoRevert.sol](./src/NoRevert.sol)

## Revert on Large Approvals & Transfers

Some tokens (e.g. `UNI`, `COMP`) revert if the value passed to `approve` or `transfer` is larger than `uint96`.

Both of the above tokens have special case logic in `approve` that sets `allowance` to `type(uint96).max`
if the approval amount is `uint256(-1)`, which may cause issues with systems that expect the value
passed to `approve` to be reflected in the `allowances` mapping.

*example*: [Uint96.sol](./src/Uint96.sol)

## Code Injection Via Token Name

Some malicious tokens have been observed to include malicious javascript in their `name` attribute,
allowing attackers to extract private keys from users who choose to interact with these tokens via
vulnerable frontends.

This has been used to exploit etherdelta users in the wild ([reference](https://hackernoon.com/how-one-hacker-stole-thousands-of-dollars-worth-of-cryptocurrency-with-a-classic-code-injection-a3aba5d2bff0)).

## Unusual Permit Function

Some tokens ([DAI, RAI, GLM, STAKE, CHAI, HAKKA, USDFL, HNY](https://github.com/yashnaman/tokensWithPermitFunctionList/blob/master/hasDAILikePermitFunctionTokenList.json)) have a `permit()` implementation that does not follow [EIP2612](https://eips.ethereum.org/EIPS/eip-2612). Tokens that do not support permit may not revert, which [could lead to the execution of later lines of code in unexpected scenarios](https://media.dedaub.com/phantom-functions-and-the-billion-dollar-no-op-c56f062ae49f). [Uniswap's Permit2](https://github.com/Uniswap/permit2) may provide a more compatible alternative.

*example*: [DaiPermit.sol](./src/DaiPermit.sol)

## Transfer of less than `amount`

Some tokens (e.g., `cUSDCv3`) contain a special case for `amount == type(uint256).max` in their transfer functions that results in only the user's balance being transferred. 

This may cause issues with systems that transfer a user-supplied `amount` to their contract and then credit the user with the same value in storage (e.g., Vault-type systems) without checking the amount that has actually been transferred.
