// Copyright (C) 2017, 2018, 2019, 2020 dbrock, rain, mrchico, d-xo
// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity >=0.6.12;

contract Math {
    // --- Math ---
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x);
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x);
    }
}

contract ERC20NoViews is Math {
    // --- ERC20 Data ---
    string private constant name = "Token";
    string private constant symbol = "TKN";
    uint8 private decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;

    event Approval(address indexed src, address indexed guy, uint wad);
    event Transfer(address indexed src, address indexed dst, uint wad);

    // --- Init ---
    constructor(uint _totalSupply) public {
        totalSupply = _totalSupply;
        balanceOf[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    // --- Token ---
    function transfer(address dst, uint wad) public virtual returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }

    function transferFrom(
        address src,
        address dst,
        uint wad
    ) public virtual returns (bool) {
        require(balanceOf[src] >= wad, "insufficient-balance");
        if (src != msg.sender && allowance[src][msg.sender] != type(uint).max) {
            require(
                allowance[src][msg.sender] >= wad,
                "insufficient-allowance"
            );
            allowance[src][msg.sender] = sub(allowance[src][msg.sender], wad);
        }
        balanceOf[src] = sub(balanceOf[src], wad);
        balanceOf[dst] = add(balanceOf[dst], wad);
        emit Transfer(src, dst, wad);
        return true;
    }

    function approve(address usr, uint wad) public virtual returns (bool) {
        allowance[msg.sender][usr] = wad;
        emit Approval(msg.sender, usr, wad);
        return true;
    }
}
