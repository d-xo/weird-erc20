// Copyright (C) 2020 d-xo
// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity >=0.6.12;

import {ERC20} from "./ERC20.sol";

contract RebasingToken is ERC20 {
    uint256 private constant MAX_UINT256 = ~uint256(0);
    uint256 private INITIAL_FRAGMENTS_SUPPLY = 50 * 10 ** 6 * 10 ** decimals;
    uint256 private _gonsPerFragment;

    // MAX_SUPPLY = maximum integer < (sqrt(4*TOTAL_GONS + 1) - 1) / 2
    uint256 public constant MAX_SUPPLY = ~uint128(0); // (2^128) - 1
    // TOTAL_GONS is a multiple of INITIAL_FRAGMENTS_SUPPLY so that _gonsPerFragment is an integer.
    // Use the highest value that fits in a uint256 for max granularity.
    uint256 private TOTAL_GONS =
        MAX_UINT256 - (MAX_UINT256 % INITIAL_FRAGMENTS_SUPPLY); // Used for authentication
    address public monetaryPolicy;

    /**
     * @param monetaryPolicy The address of the monetary policy contract to use for authentication.
     */
    modifier onlyMonetaryPolicy() {
        require(msg.sender == monetaryPolicy);
        _;
    }

    event LogRebase(uint256 epoch, uint256 totalSupply);

    // --- Init ---
    constructor(
        uint _totalSupply,
        address _monetaryPolicy
    ) public ERC20(_totalSupply) {
        monetaryPolicy = _monetaryPolicy;
    }

    // --- Token ---
    function rebase(
        uint256 epoch,
        int256 supplyDelta
    ) external onlyMonetaryPolicy returns (uint256) {
        if (supplyDelta == 0) {
            emit LogRebase(epoch, totalSupply);
            return totalSupply;
        }

        if (supplyDelta < 0) {
            totalSupply = totalSupply.sub(uint256(supplyDelta.abs()));
        } else {
            totalSupply = totalSupply.add(uint256(supplyDelta));
        }

        if (totalSupply > MAX_SUPPLY) {
            totalSupply = MAX_SUPPLY;
        }

        _gonsPerFragment = TOTAL_GONS.div(totalSupply);

        // From this point forward, _gonsPerFragment is taken as the source of truth.
        // We recalculate a new _totalSupply to be in agreement with the _gonsPerFragment
        // conversion rate.
        // This means our applied supplyDelta can deviate from the requested supplyDelta,
        // but this deviation is guaranteed to be < (_totalSupply^2)/(TOTAL_GONS - _totalSupply).
        //
        // In the case of _totalSupply <= MAX_UINT128 (our current supply cap), this
        // deviation is guaranteed to be < 1, so we can omit this step. If the supply cap is
        // ever increased, it must be re-included.
        // _totalSupply = TOTAL_GONS.div(_gonsPerFragment)

        emit LogRebase(epoch, totalSupply);
        return totalSupply;
    }
}
