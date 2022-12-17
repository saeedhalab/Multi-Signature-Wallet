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

    function submitOwnerForm(
        bytes memory _desc,
        uint8 _suggNumConfirmRequired,
        address _ownerAddress,
        bool _isSubmitRemovedOwnerForm
    )
        public
        onlyOwner(msg.sender)
        isValidNumConfirmaionRequired(
            _suggNumConfirmRequired,
            _isSubmitRemovedOwnerForm
        )
    {
        require(_ownerAddress != address(0), "address not valid");
        uint256 id = ownerForms.length;
        uint64 expireTime = uint64((block.timestamp) + 1 weeks);
        ownerForms.push(
            ownerForm({
                desc: _desc,
                numConfirmationsRequired: _suggNumConfirmRequired,
                numConfirmation: 0,
                expireTime: expireTime,
                ownerAddress: _ownerAddress,
                isExpire: false,
                isRemoveOwner: _isSubmitRemovedOwnerForm
            })
        );
        emit SubmitOwnerForm(
            _ownerAddress,
            id,
            _desc,
            _suggNumConfirmRequired,
            expireTime,
            _isSubmitRemovedOwnerForm
        );
    }

    function confirmOwnerForm(uint256 _formId)
        public
        onlyOwner(msg.sender)
        isExistForm(_formId)
        isNotExpireForm(_formId)
        isNotConfirmOwnerForm(_formId)
    {
        ownerForm storage form = ownerForms[_formId];
        form.numConfirmation++;
        isConfirmOwnerForm[_formId][msg.sender] = true;
        emit ConfirmOwnerForm(_formId, msg.sender);
        if (form.numConfirmation >= numConfirmationsRequired) {
            _excuteOwnerForm(_formId);
        }
    }

    function revokeOwnerForm(uint256 _formId)
        public
        onlyOwner(msg.sender)
        isExistForm(_formId)
        isNotExpireForm(_formId)
    {
        require(isConfirmOwnerForm[_formId][msg.sender], "is not confirm form");
        ownerForm storage form = ownerForms[_formId];
        form.numConfirmation--;
        isConfirmOwnerForm[_formId][msg.sender] = false;
        emit RevokeOwnerFormConfirmation(_formId, msg.sender);
    }

    function _excuteOwnerForm(uint256 _formId) private {
        ownerForm storage form = ownerForms[_formId];
        form.isExpire = true;
        numConfirmationsRequired = form.numConfirmationsRequired;
        if (form.isRemoveOwner) {
            _deleteOwner(form.ownerAddress);
        } else {
            owners.push(form.ownerAddress);
        }
        emit ExcuteOwnerForm(_formId, msg.sender, form.ownerAddress);
    }

    function _deleteOwner(address _owner) private {
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == _owner) {
                delete owners[i];
                return;
            }
        }
    }

    function getOwnerForm(uint256 _formId)
        public
        view
        isExistForm(_formId)
        returns (
            bytes memory _desc,
            uint8 _numConfirmation,
            uint8 _numConfirmationsRequired,
            uint64 _expireTime,
            bool _isRemoveOwne,
            bool _isExpire,
            address _ownerAddress
        )
    {
        ownerForm memory form = ownerForms[_formId];
        return (
            form.desc,
            form.numConfirmation,
            form.numConfirmationsRequired,
            form.expireTime,
            form.isRemoveOwner,
            form.isExpire,
            form.ownerAddress
        );
    }

    function getOwnersCount() public view returns (uint256) {
        return owners.length;
    }
}
