// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract mwallet {
    // defining my contract events
    event Deposit(address indexed sender, uint amount, uint balance);
    event SubmitTransaction(
        address indexed owner,
        uint indexed transIndex,
        address indexed to,
        uint value,
        bytes data
    );
    event ConfirmTransaction(address indexed owner, uint indexed transIndex);
    event RevokeConfirmation(address indexed owner, uint indexed transIndex);
    event ExecuteTransaction(address indexed owner, uint indexed transIndex);

    // creating a list of wallet owners and mapping their addresses to a boolean name isOwner

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint public minConfirmations;

    // creating transaction structure

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        uint numConfirmations;
    }
    //  mapping transaction to the owner then to the boolean
    mapping(uint => mapping(address => bool)) public isConfirmed;

    Transaction[] public transactions;
    // checks if the person submiting transaction is one of owners
    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }
    // checks if  submitted transaction exists
    modifier transExists(uint _transIndex) {
        require(
            _transIndex < transactions.length,
            "transaction does not exist"
        );
        _;
    }
    // checks if  submitted transaction has not been exectuted
    modifier notExecuted(uint _transIndex) {
        require(
            !transactions[_transIndex].executed,
            "transaction already executed"
        );
        _;
    }
    // checks if  submitted transaction has no been confirmed
    modifier notConfirmed(uint _transIndex) {
        require(
            !isConfirmed[_transIndex][msg.sender],
            "transaction already confirmed"
        );
        _;
    }

    constructor(address[] memory _owners, uint _minConfirmations) {
        require(_owners.length > 0, "owners required");
        require(
            _minConfirmations > 0 && _minConfirmations <= _owners.length,
            "invalid number of required confirmations"
        );

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        minConfirmations = _minConfirmations;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    // function for submitting transaction
    function submitTransaction(
        address _to,
        uint _value,
        bytes memory _data
    ) public onlyOwner {
        uint transIndex = transactions.length;

        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                numConfirmations: 0
            })
        );

        emit SubmitTransaction(msg.sender, transIndex, _to, _value, _data);
    }

    // function for transaction confirmation
    function confirmTransaction(
        uint _transIndex
    )
        public
        onlyOwner
        transExists(_transIndex)
        notExecuted(_transIndex)
        notConfirmed(_transIndex)
    {
        Transaction storage transaction = transactions[_transIndex];
        transaction.numConfirmations += 1;
        isConfirmed[_transIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _transIndex);
    }

    // function for executing transaction
    function executeTransaction(
        uint _transIndex
    ) public onlyOwner transExists(_transIndex) notExecuted(_transIndex) {
        Transaction storage transaction = transactions[_transIndex];

        require(
            transaction.numConfirmations >= minConfirmations,
            "cannot execute tx"
        );

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "transaction failed");

        emit ExecuteTransaction(msg.sender, _transIndex);
    }

    // function for revoking confirmation
    function revokeConfirmation(
        uint _transIndex
    ) public onlyOwner transExists(_transIndex) notExecuted(_transIndex) {
        Transaction storage transaction = transactions[_transIndex];

        require(
            isConfirmed[_transIndex][msg.sender],
            "transaction not confirmed"
        );

        transaction.numConfirmations -= 1;
        isConfirmed[_transIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _transIndex);
    }

    // function for retrieving owners addresses
    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    // function for counting transactions
    function getTransactionCount() public view returns (uint) {
        return transactions.length;
    }

    // function for retrieving specific transaction
    function getTransaction(
        uint _transIndex
    )
        public
        view
        returns (
            address to,
            uint value,
            bytes memory data,
            bool executed,
            uint numConfirmations
        )
    {
        Transaction storage transaction = transactions[_transIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
        );
    }
}
