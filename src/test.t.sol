// Copyright (C) 2020 d-xo
// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity >=0.6.12;

import {DSTest} from "ds-test/test.sol";
import {ProxiedToken, TokenProxy} from "./Proxied.sol";

interface ERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract User {
    ERC20 token;
    constructor(ERC20 _token) public {
        token = _token;
    }

    function transfer(address dst, uint amt) external returns (bool) {
        return token.transfer(dst, amt);
    }

    function transferFrom(address src, address dst, uint amt) external returns (bool) {
        return token.transferFrom(src, dst, amt);
    }

    function approve(address usr, uint amt) external returns (bool) {
        return token.approve(usr, amt);
    }
}

contract TestProxy is DSTest {
    ProxiedToken underlying;
    ERC20 proxy1;
    ERC20 proxy2;
    User user1;
    User user2;

    function setUp() public {
        underlying = new ProxiedToken(type(uint256).max);

        proxy1 = ERC20(address(new TokenProxy(address(underlying))));
        proxy2 = ERC20(address(new TokenProxy(address(underlying))));

        underlying.setDelegator(address(proxy1), true);
        underlying.setDelegator(address(proxy2), true);

        user1 = new User(proxy1);
        user2 = new User(proxy2);

        proxy1.transfer(address(user1), proxy1.totalSupply() / 2);
        proxy2.transfer(address(user1), proxy1.totalSupply() / 2);
    }

    function testProxy(uint128 amt) public {
        assertEq(proxy1.balanceOf(address(user1)), proxy2.balanceOf(address(user1)));
        assertEq(proxy1.balanceOf(address(user2)), proxy2.balanceOf(address(user2)));

        uint preBal1 = proxy2.balanceOf(address(user1));
        uint preBal2 = proxy1.balanceOf(address(user2));

        user1.transfer(address(user2), amt);
        assertEq(proxy2.balanceOf(address(user1)), preBal1 - amt);
        assertEq(proxy1.balanceOf(address(user2)), preBal2 + amt);
    }
}
