// Copyright (C) 2017, 2018, 2019, 2020 dbrock, rain, mrchico, xvwx
// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.6.12;

contract ProxiedToken {
    // --- ERC20 Data ---
    string  public constant name = "Token";
    string  public constant symbol = "TKN";
    uint8   public constant decimals = 18;
    uint256 public totalSupply;

    mapping (address => uint)                      public balanceOf;
    mapping (address => mapping (address => uint)) public allowance;

    event Approval(address indexed src, address indexed guy, uint wad);
    event Transfer(address indexed src, address indexed dst, uint wad);

    // --- Math ---
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x);
    }
    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x);
    }

    // --- Init ---
    constructor(uint _totalSupply) public {
        owners[msg.sender] = true;
        totalSupply = _totalSupply;
        balanceOf[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    // --- Access Control ---
    mapping(address => bool) public owners;
    mapping(address => bool) public delegators;

    modifier onlyOwner() { require(owners[msg.sender], "non-owner-call"); _; }
    modifier delegated() { require(delegators[msg.sender], "non-delegator-call"); _; }

    function setOwner(address owner, bool status) external onlyOwner
    {
        owners[owner] = status;
    }
    function setDelegator(address delegator, bool status) external onlyOwner
    {
        delegators[delegator] = status;
    }

    // --- Token ---
    function transfer(address caller, address dst, uint wad) delegated external returns (bool) {
        return transferFrom(caller, caller, dst, wad);
    }
    function transferFrom(
        address caller, address src, address dst, uint wad
    ) delegated public returns (bool) {
        require(balanceOf[src] >= wad, "insufficient-balance");
        if (src != caller && allowance[src][caller] != uint(-1)) {
            require(allowance[src][caller] >= wad, "insufficient-allowance");
            allowance[src][caller] = sub(allowance[src][caller], wad);
        }
        balanceOf[src] = sub(balanceOf[src], wad);
        balanceOf[dst] = add(balanceOf[dst], wad);
        emit Transfer(src, dst, wad);
        return true;
    }
    function approve(address caller, address usr, uint wad) delegated external returns (bool) {
        allowance[caller][usr] = wad;
        emit Approval(caller, usr, wad);
        return true;
    }
}

contract TokenProxy {
    address payable public impl;
    constructor(address payable _impl) public {
        impl = _impl;
    }
    fallback() external payable {
        address _impl = impl; // pull impl onto the stack
        assembly {
            // get free data pointer
            let ptr := mload(0x40)

            // write the function selector to ptr
            calldatacopy(ptr, 0, 4)
            // store msg.sender at ptr + 4
            mstore(add(ptr, 4), caller())
            // write the rest of the calldata
            calldatacopy(add(ptr, 24), 4, sub(calldatasize(), 4))

            // call impl with the contents of ptr as caldata
            let result := call(gas(), _impl, callvalue(), ptr, add(calldatasize(), 20), 0, 0)

            // copy the returndata to ptr
            let size := returndatasize()
            returndatacopy(ptr, 0, size)

            switch result
            // revert if the call failed
            case 0 { revert(ptr, size) }
            // return ptr otherwise
            default { return(ptr, size) }
        }
    }
}
