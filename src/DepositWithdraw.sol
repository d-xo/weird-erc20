// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract DepositWithdraw is Ownable(msg.sender), ReentrancyGuard {
    mapping(address => uint256) private _balances;

    event Deposited(address indexed depositor, uint256 amount);
    event Withdrew(address indexed withdrawer, uint256 amount);

    function deposit() public payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        _balances[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) public nonReentrant {
        require(amount <= _balances[msg.sender], "Insufficient balance");
        _balances[msg.sender] -= amount;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed.");
        emit Withdrew(msg.sender, amount);
    }

    function transferOwnership(address newOwner) public onlyOwner override {
        transferOwnership(newOwner);
    }

    function getBalance() public view returns (uint256) {
        return _balances[msg.sender];
    }
}