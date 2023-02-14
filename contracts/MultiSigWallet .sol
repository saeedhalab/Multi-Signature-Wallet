// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract MultiSigWallet {
    event Deposit(address sender, uint256 amount, uint256 balance);
    event ExcuteTransaction(uint256 txIndex, address owner);
    event RevokeConfirmation(uint256 txIndex, address owner);
    event ConfirmTransaction(
        uint256 txIndex,
        address owner,
        uint8 numConfirmations
    );
    event ConfirmOwnerForm(uint256 formIndex, address owner);
    event RevokeOwnerFormConfirmation(uint256 formIndex, address owner);
    event ExcuteOwnerForm(uint256 formId, address owner, address suggesOwner);
    event SubmitTransaction(
        address owner,
        address to,
        uint256 txIndex,
        uint256 value,
        uint64 expierTime
    );
    event SubmitOwnerForm(
        address suggesOwner,
        uint256 formIndex,
        string desc,
        uint8 suggNumConfirmationsRequired,
        uint256 expireTime,
        bool isRemovedOwner
    );

    address[] public owners;
    uint8 public NumConfirmationsRequired;
    struct Transaction {
        address to;
        uint256 value;
        uint64 expireTime;
        uint8 numConfirmations;
        bool executed;
    }
    struct ownerForm {
        string desc;
        uint8 numConfirmation;
        uint8 suggNumConfirmationsRequired;
        uint64 expireTime;
        bool isRemoveOwner;
        bool executed;
        address suggOwnerAddress;
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
    modifier isNotConfirm(uint256 txIndex) {
        require(!isConfirm[txIndex][msg.sender], "tx already confirmed");
        _;
    }
    modifier isNotExcute(uint256 txIndex) {
        require(!transactions[txIndex].executed, "tx already excuted");
        _;
    }
    modifier isNotExpire(uint256 txIndex) {
        uint64 nowTime = uint64(block.timestamp);
        require(
            nowTime < transactions[txIndex].expireTime,
            "The tx has expired"
        );
        _;
    }
    modifier isExistTransaction(uint256 txIndex) {
        require(transactions.length >= txIndex, "tx does not exist");
        _;
    }
    modifier isExistForm(uint256 formIndex) {
        require(ownerForms.length >= formIndex, "form does not exist");
        _;
    }
    modifier isNotConfirmOwnerForm(uint256 formIndex) {
        require(
            !isConfirmOwnerForm[formIndex][msg.sender],
            "tx already confirmed"
        );
        _;
    }
    modifier isNotExpireForm(uint256 formIndex) {
        uint64 nowTime = uint64(block.timestamp);
        require(
            nowTime < ownerForms[formIndex].expireTime,
            "The form has expired"
        );
        _;
    }
    modifier isNotExcuteOwnerForm(uint256 formIndex) {
        require(!ownerForms[formIndex].executed, "form already excuted");
        _;
    }
    modifier isValidNumConfirmaionRequired(
        uint8 numConfirmRequire,
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
            ownersNum >= numConfirmRequire && numConfirmRequire > 1,
            "numConfirmRequire is invalid"
        );
        uint8 num = ownersNum % 2;

        if (num == 0) {
            minConfrimation = (ownersNum / 2) + 1;
        } else {
            minConfrimation = (ownersNum + 1) / 2;
        }
        require(
            numConfirmRequire >= minConfrimation &&
                numConfirmRequire <= ownersNum,
            "numConfirmRequire is invalid"
        );
        _;
    }

    constructor(
        address[] memory _owners,
        uint8 _numConfirmationRequired
    ) payable {
        require(_owners.length > 1, "owners required");
        require(
            _numConfirmationRequired <= _owners.length &&
                _numConfirmationRequired > 0,
            "invalid number of required confirmations"
        );
        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "invalid owner address");
            require(!isOwner[owner], "owner not unique");
            isOwner[owner] = true;
            owners.push(owner);
        }
        NumConfirmationsRequired = _numConfirmationRequired;
    }

    function submitTransaction(
        address _to,
        uint256 _value
    ) public onlyOwner(msg.sender) {
        require(address(this).balance >= _value, "balance not enough");
        uint256 txId = transactions.length;
        uint64 expireTime = uint64((block.timestamp) + 1 weeks);
        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                expireTime: expireTime,
                executed: false,
                numConfirmations: 0
            })
        );
        emit SubmitTransaction(msg.sender, _to, txId, _value, expireTime);
    }

    function confirmTransaction(
        uint256 _txId
    )
        public
        onlyOwner(msg.sender)
        isExistTransaction(_txId)
        isNotExpire(_txId)
        isNotExcute(_txId)
        isNotConfirm(_txId)
    {
        Transaction storage transaction = transactions[_txId];
        transaction.numConfirmations += 1;
        isConfirm[_txId][msg.sender] = true;
        emit ConfirmTransaction(
            _txId,
            msg.sender,
            transaction.numConfirmations
        );
    }

    function revokeTransaction(
        uint256 _txIndex
    )
        public
        onlyOwner(msg.sender)
        isNotExpire(_txIndex)
        isExistTransaction(_txIndex)
        isNotExcute(_txIndex)
    {
        require(isConfirm[_txIndex][msg.sender], "tx not confirmed");
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations -= 1;
        isConfirm[_txIndex][msg.sender] = false;
        emit RevokeConfirmation(_txIndex, msg.sender);
    }

    function excuteTransaction(
        uint256 _txIndex
    )
        public
        payable
        onlyOwner(msg.sender)
        isNotExpire(_txIndex)
        isExistTransaction(_txIndex)
        isNotExcute(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        require(
            transaction.numConfirmations >= NumConfirmationsRequired,
            "Confirmation is not enough"
        );
        transaction.executed = true;
        (bool success, ) = transaction.to.call{value: transaction.value}("");

        require(success, "tx failed");
        emit ExcuteTransaction(_txIndex, msg.sender);
    }

    function getTransaction(
        uint256 _txIndex
    )
        public
        view
        returns (address to, uint256 value, uint8 numConfirmation, bool excuted)
    {
        Transaction memory transaction = transactions[_txIndex];
        return (
            transaction.to,
            transaction.value,
            transaction.numConfirmations,
            transaction.executed
        );
    }

    function submitOwnerForm(
        string memory _desc,
        uint8 _suggNumConfirmRequired,
        address _suggOwnerAddress,
        bool _isSubmitRemovedOwnerForm
    )
        public
        onlyOwner(msg.sender)
        isValidNumConfirmaionRequired(
            _suggNumConfirmRequired,
            _isSubmitRemovedOwnerForm
        )
    {
        require(_suggOwnerAddress != address(0), "address invalid");
        if (_isSubmitRemovedOwnerForm) {
            require(isOwner[_suggOwnerAddress], "address invalid");
        }
        uint256 id = ownerForms.length;
        uint64 expireTime = uint64((block.timestamp) + 1 weeks);
        ownerForms.push(
            ownerForm({
                desc: _desc,
                suggNumConfirmationsRequired: _suggNumConfirmRequired,
                numConfirmation: 0,
                expireTime: expireTime,
                suggOwnerAddress: _suggOwnerAddress,
                executed: false,
                isRemoveOwner: _isSubmitRemovedOwnerForm
            })
        );
        emit SubmitOwnerForm(
            _suggOwnerAddress,
            id,
            _desc,
            _suggNumConfirmRequired,
            expireTime,
            _isSubmitRemovedOwnerForm
        );
    }

    function confirmOwnerForm(
        uint256 _formIndex
    )
        public
        onlyOwner(msg.sender)
        isExistForm(_formIndex)
        isNotExcuteOwnerForm(_formIndex)
        isNotExpireForm(_formIndex)
        isNotConfirmOwnerForm(_formIndex)
    {
        ownerForm storage form = ownerForms[_formIndex];
        form.numConfirmation++;
        isConfirmOwnerForm[_formIndex][msg.sender] = true;
        emit ConfirmOwnerForm(_formIndex, msg.sender);
    }

    function revokeOwnerForm(
        uint256 _formIndex
    )
        public
        onlyOwner(msg.sender)
        isExistForm(_formIndex)
        isNotExpireForm(_formIndex)
        isNotExcuteOwnerForm(_formIndex)
    {
        require(
            isConfirmOwnerForm[_formIndex][msg.sender],
            "is not confirm form"
        );
        ownerForm storage form = ownerForms[_formIndex];
        form.numConfirmation--;
        isConfirmOwnerForm[_formIndex][msg.sender] = false;
        emit RevokeOwnerFormConfirmation(_formIndex, msg.sender);
    }

    function excuteOwnerForm(
        uint256 _formIndex
    )
        public
        onlyOwner(msg.sender)
        isExistForm(_formIndex)
        isNotExpireForm(_formIndex)
        isNotExcuteOwnerForm(_formIndex)
    {
        ownerForm storage form = ownerForms[_formIndex];
        require(
            form.numConfirmation >= NumConfirmationsRequired,
            "Confirmation is not enough"
        );
        form.executed = true;
        NumConfirmationsRequired = form.suggNumConfirmationsRequired;
        if (form.isRemoveOwner) {
            _deleteOwner(form.suggOwnerAddress);
            isOwner[form.suggOwnerAddress] = false;
        } else {
            owners.push(form.suggOwnerAddress);
            isOwner[form.suggOwnerAddress] = true;
        }
        emit ExcuteOwnerForm(_formIndex, msg.sender, form.suggOwnerAddress);
    }

    function _deleteOwner(address _owner) private {
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == _owner) {
                delete owners[i];
                owners[i] = owners[owners.length - 1];
                owners.pop();
                return;
            }
        }
    }

    function getOwnerForm(
        uint256 _formIndex
    )
        public
        view
        isExistForm(_formIndex)
        returns (
            string memory _desc,
            uint8 _numConfirmation,
            uint8 _suggNumConfirmationsRequired,
            uint64 _expireTime,
            bool _isRemoveOwne,
            bool _executed,
            address _ownerAddress
        )
    {
        ownerForm memory form = ownerForms[_formIndex];
        return (
            form.desc,
            form.numConfirmation,
            form.suggNumConfirmationsRequired,
            form.expireTime,
            form.isRemoveOwner,
            form.executed,
            form.suggOwnerAddress
        );
    }

    function getOwnersCount() public view returns (uint256) {
        return owners.length;
    }

    receive() external payable {}

    fallback() external payable {}
}
