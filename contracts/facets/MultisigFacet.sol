// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/LibMultisigStorage.sol";

contract MultisigFacet {
    uint constant public MAX_OWNER_COUNT = 50;

    event Confirmation(address indexed sender, uint indexed transactionId);
    event Revocation(address indexed sender, uint indexed transactionId);
    event Submission(uint indexed transactionId);
    event Execution(uint indexed transactionId);
    event ExecutionFailure(uint indexed transactionId);
    event Deposit(address indexed sender, uint value);
    event OwnerAddition(address indexed owner);
    event OwnerRemoval(address indexed owner);
    event RequirementChange(uint required);

    modifier onlyWallet() {
        require(msg.sender == address(this), "MultisigFacet: Only wallet can call");
        _;
    }

    modifier ownerDoesNotExist(address owner) {
        require(!LibMultisigStorage.layout().isOwner[owner], "MultisigFacet: Owner already exists");
        _;
    }

    modifier ownerExists(address owner) {
        require(LibMultisigStorage.layout().isOwner[owner], "MultisigFacet: Owner does not exist");
        _;
    }

    modifier transactionExists(uint transactionId) {
        require(LibMultisigStorage.layout().transactions[transactionId].destination != address(0), "MultisigFacet: Transaction does not exist");
        _;
    }

    modifier confirmed(uint transactionId, address owner) {
        require(LibMultisigStorage.layout().confirmations[transactionId][owner], "MultisigFacet: Not confirmed");
        _;
    }

    modifier notConfirmed(uint transactionId, address owner) {
        require(!LibMultisigStorage.layout().confirmations[transactionId][owner], "MultisigFacet: Already confirmed");
        _;
      }

    modifier notExecuted(uint transactionId) {
        require(!LibMultisigStorage.layout().transactions[transactionId].executed, "MultisigFacet: Already executed");
        _;
    }

    modifier validRequirement(uint ownerCount, uint _required) {
        require(ownerCount <= MAX_OWNER_COUNT 
            && _required <= ownerCount 
            && _required != 0 
            && ownerCount != 0, "MultisigFacet: Invalid requirement");
        _;
    }

    function initializeMultisig(address[] memory _owners, uint _required) 
        external 
        validRequirement(_owners.length, _required)
    {
        LibMultisigStorage.Layout storage l = LibMultisigStorage.layout();
            
        for (uint i = 0; i < _owners.length; i++) {
            require(!l.isOwner[_owners[i]] && _owners[i] != address(0), "MultisigFacet: Invalid owner");
            l.isOwner[_owners[i]] = true;
        }
        
        l.owners = _owners;
        l.required = _required;
    }

    function submitTransaction(address destination, uint value, bytes memory data)
        public
        returns (uint transactionId)
    {
        transactionId = _addTransaction(destination, value, data);
        confirmTransaction(transactionId, false);
    }

    function confirmTransaction(uint transactionId, bool executeIfReady)
        public
        ownerExists(msg.sender)
        transactionExists(transactionId)
        notConfirmed(transactionId, msg.sender)
    {
        LibMultisigStorage.Layout storage l = LibMultisigStorage.layout();
        l.confirmations[transactionId][msg.sender] = true;
        
        emit Confirmation(msg.sender, transactionId);
        
        if (executeIfReady && _isConfirmed(transactionId)) {
            _executeTransaction(transactionId);
        }
    }

    function executeTransaction(uint transactionId)
        public
        ownerExists(msg.sender)
        transactionExists(transactionId)
        notExecuted(transactionId)
    {        
        _executeTransaction(transactionId);
    }

    function _executeTransaction(uint transactionId) internal {
        if (_isConfirmed(transactionId)) {
            LibMultisigStorage.Layout storage l = LibMultisigStorage.layout();
            LibMultisigStorage.Transaction storage txn = l.transactions[transactionId];
            
            txn.executed = true;
            (bool success, ) = txn.destination.call{value: txn.value}(txn.data);
            
            if (success) {
                emit Execution(transactionId);
            } else {
                emit ExecutionFailure(transactionId);
                txn.executed = false;
            }
        }
    }

    function _isConfirmed(uint transactionId) internal view returns (bool) {
        LibMultisigStorage.Layout storage l = LibMultisigStorage.layout();
        uint count = 0;
        
        for (uint i = 0; i < l.owners.length; i++) {
            if (l.confirmations[transactionId][l.owners[i]]) {
                count++;
            }
            
            if (count == l.required) {
                return true;
            }
        }
        
        return false;
    }

    function _addTransaction(address destination, uint value, bytes memory data)
        internal
        returns (uint transactionId)
    {
        LibMultisigStorage.Layout storage l = LibMultisigStorage.layout();
        
        require(destination != address(0), "MultisigFacet: Invalid destination");
        
        transactionId = l.transactionCount;
        l.transactions[transactionId] = LibMultisigStorage.Transaction({
            destination: destination,
            value: value,
            data: data,
            executed: false
        });
        
        l.transactionCount++;
        emit Submission(transactionId);
        
        return transactionId;
    }

    // Additional view functions can be added here
    function getOwners() external view returns (address[] memory) {
        return LibMultisigStorage.layout().owners;
    }

    function getTransactionCount(bool pending, bool executed) external view returns (uint count) {
        LibMultisigStorage.Layout storage l = LibMultisigStorage.layout();
        
        for (uint i = 0; i < l.transactionCount; i++) {
            if ((pending && !l.transactions[i].executed) || 
                (executed && l.transactions[i].executed)) {
                count++;
            }
        }
    }
}