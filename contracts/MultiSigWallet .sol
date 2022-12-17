// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract MultiSigWallet {
    event Deposit(address sender, uint256 amount, uint256 balance);
    event ExcuteTransaction(uint256 txId, address owner);
    event RevokeConfirmation(uint256 txId, address owner);
    event ConfirmTransaction(uint256 txId, address owner);
    event ConfirmOwnerForm(uint256 txId, address owner);
    event RevokeOwnerFormConfirmation(uint256 txId, address owner);
    event ExcuteOwnerForm(uint256 formId, address owner, address suggesOwner);
    event SubmitTransaction(
        address owner,
        address to,
        uint256 txId,
        uint256 value,
        bytes data
    );
    event SubmitOwnerForm(
        address suggesOwner,
        uint256 txId,
        bytes desc,
        uint8 numConfirmationsRequired,
        uint256 expireTime,
        bool isRemovedOwner
    );

    address[] public owners;
    uint8 public numConfirmationsRequired;
    struct Transaction {
        address to;
        uint64 value;
        uint8 numConfirmations;
        bytes data;
        bool executed;
    }
    struct ownerForm {
        bytes desc;
        uint8 numConfirmation;
        uint8 numConfirmationsRequired;
        uint64 expireTime;
        bool isRemoveOwner;
        bool isExpire;
        address ownerAddress;
    }
    mapping(address => bool) isOwner;
    // mapping from tx index => owner => bool
    mapping(uint256 => mapping(address => bool)) isConfirm;
    mapping(uint256 => mapping(address => bool)) isConfirmOwnerForm;
    Transaction[] transactions;
    ownerForm[] ownerForms;

    modifier onlyOwner(address owner) {
        require(isOwner[owner]);
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
    modifier isExistTransaction(uint256 txIndex) {
        require(transactions.length <= txIndex, "tx does not exist");
        _;
    }
    modifier isExistForm(uint256 _formId) {
        require(ownerForms.length <= _formId, "form does not exist");
        _;
    }
    modifier isNotConfirmOwnerForm(uint256 _formId) {
        require(
            !isConfirmOwnerForm[_formId][msg.sender],
            "tx already confirmed"
        );
        _;
    }
    modifier isNotExpireForm(uint256 _formId) {
        uint64 nowTime = uint64((block.timestamp) + 1 weeks);
        require(
            nowTime < ownerForms[_formId].expireTime &&
                !ownerForms[_formId].isExpire,
            "form dos expired"
        );
        _;
    }
    modifier isValidNumConfirmaionRequired(
        uint8 _numConfirmRequire,
        bool isRemoved
    ) {
        uint8 ownersNum;
        uint8 minConfrimation;
        if (isRemoved) {
            ownersNum = uint8(owners.length) - 1;
        } else {
            ownersNum = uint8(owners.length) + 1;
        }
        require(ownersNum >= 2, "min owner is two");
        require(
            ownersNum >= _numConfirmRequire && _numConfirmRequire > 1,
            "numConfirmRequire is invalid"
        );
        uint8 num = ownersNum % 2;

        if (num == 0) {
            minConfrimation = (ownersNum / 2) + 1;
        } else {
            minConfrimation = (ownersNum + 1) / 2;
        }
        require(
            _numConfirmRequire >= minConfrimation &&
                _numConfirmRequire <= ownersNum,
            "numConfirmRequire is invalid"
        );
        _;
    }

    constructor(address[] memory _owners, uint8 _numConfirmationRequired) {
        require(_owners.length > 1, "owners required");
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
    ) public onlyOwner(msg.sender) {
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
        onlyOwner(msg.sender)
        isExistTransaction(_txId)
        isNotExcute(_txId)
        isNotConfirm(_txId)
    {
        Transaction storage transaction = transactions[_txId];
        transaction.numConfirmations += 1;
        isConfirm[_txId][msg.sender] = true;
        emit ConfirmTransaction(_txId, msg.sender);
        if (transaction.numConfirmations >= numConfirmationsRequired) {
            _excuteTransaction(_txId);
        }
    }

    function revokeTransaction(uint256 _txId)
        public
        onlyOwner(msg.sender)
        isExistTransaction(_txId)
        isNotExcute(_txId)
    {
        require(isConfirm[_txId][msg.sender], "tx not confirmed");
        Transaction storage transaction = transactions[_txId];
        transaction.numConfirmations -= 1;
        isConfirm[_txId][msg.sender] = false;
        emit RevokeConfirmation(_txId, msg.sender);
    }

    function _excuteTransaction(uint256 _txId)
        private
        onlyOwner(msg.sender)
        isExistTransaction(_txId)
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
