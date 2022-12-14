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
    uint8 public numConfirmationsRequired;
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
        require(!isConfirm[txId][msg.sender], "tx already confirmed");
        _;
    }
    modifier isNotExcute(uint256 txId) {
        require(!transactions[txId].excuted, "tx already excuted");
        _;
    }
    modifier toExist(uint256 txIndex) {
        require(transactions.length <= txIndex, "tx does not exist");
        _;
    }

    constructor(address[] memory _owners, uint8 _numConfirmationRequired) {
        require(_owners.length > 0, "owners required");
        require(
            _numConfirmationRequired <= _owners.length &&
                _numConfirmationRequired > 0,
            "invalid number of required confirmations"
        );
        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner not unique");
            isOwner[owner] = true;
            owners.push(owner);
        }
        numConfirmationsRequired = _numConfirmationRequired;
    }
}
