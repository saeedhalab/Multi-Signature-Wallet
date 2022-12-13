// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract MultiSigWallet {
    event Deposit(address sender, uint256 amount, uint256 balance);
    event ExcuteTransaction(uint256 txId, address owner);
    event RevokeConfirmation(uint256 txId, address owner);
    event ConfirmTransaction(uint256 txId, address owner);
    event SubmitTransaction(
        address owner,
        address to,
        uint256 txId,
        uint256 value,
        bytes data
    );
    event AddOwner(address owner, address newOwner);
    //event RemoveOwner(address owner,address newOwner);

    address[] public owners;
    uint8 ConfirmationCount;
    struct Transaction {
        address to;
        uint64 value;
        uint64 id;
        uint8 numConfirmation;
        bytes data;
        bool excuted;
    }
    mapping(address => bool) isOwner;
    // mapping from tx index => owner => bool
    mapping(uint256 => mapping(address => bool)) isConfirm;
    Transaction[] transactions;

    modifier onlyOwner() {
        require(isOwner[msg.sender]);
        _;
    }
    modifier isNotConfirm(uint256 txId) {
        require(!isConfirm[txId][msg.sender],"tx already confirmed");
        _;
    }
    modifier isNotExcute(uint256 txId) {
        require(!transactions[txId].excuted,"tx already excuted");
        _;
    }
    modifier toExist(uint txIndex)[
        require(transactions.length<=txIndex,"tx does not exist");
        _;
    ]
}
