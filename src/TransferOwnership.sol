// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract TransferOwnership is Ownable(msg.sender), ReentrancyGuard {
    mapping(address => uint256) private _balances;

    event Deposit(address indexed depositor, uint256 amount);
    event Withdraw(address indexed withdrawer, uint256 amount);
    event ownershipTransferred(address indexed owner, address indexed newOwner);

    function deposit() public payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        _balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function isContract(address _addr) private view returns (bool){
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    function withdraw(uint256 amount) public nonReentrant {
        require(amount <= _balances[msg.sender], "Insufficient balance");
    
        // Check if the recipient address is not a contract
        require(!isContract(msg.sender), "Contract addresses are not allowed to withdraw funds");
    
        _balances[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
        emit Withdraw(msg.sender, amount);
    }


    function transferOwnership(address newOwner) public onlyOwner override {
        require(newOwner == address(0),"invalid address");
        _transferOwnership(newOwner);
        emit ownershipTransferred(msg.sender, newOwner);
    }

    function getBalance() public view returns (uint256) {
        return _balances[msg.sender];
    }
}