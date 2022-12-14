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
        uint8 numConfirmations;
        bytes data;
        bool executed;
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
        require(!transactions[txId].executed, "tx already excuted");
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

    function submitTransaction(
        address _to,
        uint64 _value,
        bytes memory _data
    ) public onlyOwner {
        uint256 txId = transactions.length;
        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                numConfirmations: 0
            })
        );
        emit SubmitTransaction(msg.sender, _to, txId, _value, _data);
    }

    function confirmTransaction(uint256 _txId)
        public
        onlyOwner
        toExist(_txId)
        isNotExcute(_txId)
        isNotConfirm(_txId)
    {
        Transaction storage transaction = transactions[_txId];
        transaction.numConfirmations += 1;
        isConfirm[_txId][msg.sender] = true;
        emit ConfirmTransaction(_txId, msg.sender);
    }

    function revokeTransaction(uint256 _txId)
        public
        onlyOwner
        toExist(_txId)
        isNotExcute(_txId)
    {
        require(isConfirm[_txId][msg.sender], "tx not confirmed");
        Transaction storage transaction = transactions[_txId];
        transaction.numConfirmations -= 1;
        isConfirm[_txId][msg.sender] = false;
        emit RevokeConfirmation(_txId, msg.sender);
    }

    function excuteTransaction(uint256 _txId)
        public
        onlyOwner
        toExist(_txId)
        isNotExcute(_txId)
    {
        Transaction storage transaction = transactions[_txId];
        require(
            transaction.numConfirmations >= numConfirmationsRequired,
            "cannot execute tx"
        );
        transaction.executed = true;
        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "tx failed");
        emit ExcuteTransaction(_txId, msg.sender);
    }

    function getTransaction(uint256 _txId)
        public
        view
        returns (
            address to,
            uint64 value,
            uint8 numConfirmation,
            bytes memory data,
            bool excuted
        )
    {
        Transaction memory transaction = transactions[_txId];
        return (
            transaction.to,
            transaction.value,
            transaction.numConfirmations,
            transaction.data,
            transaction.executed
        );
    }
}
