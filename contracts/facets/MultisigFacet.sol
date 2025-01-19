// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/LibMultisigStorage.sol";
import "../interfaces/IERC20.sol";
import "forge-std/console.sol";

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
    error ErrorTxnotConfirmed(uint transactionId);

    modifier onlyWallet() {
        require(msg.sender == address(this), "MultisigFacet: Only wallet can call");
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

    function initializeMultisig(address erc20Address, uint _required) 
        external 
    {
        LibMultisigStorage.Layout storage l = LibMultisigStorage.layout();
        
        require(erc20Address != address(0), "MultisigFacet: Invalid ERC20 address");
        l.required = _required;
        l.erc20Address = erc20Address;
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
        transactionExists(transactionId)
        notConfirmed(transactionId, msg.sender)
    {
        LibMultisigStorage.Layout storage l = LibMultisigStorage.layout();
        uint256 balance = IERC20(l.erc20Address).balanceOf(msg.sender); // Check ERC20 balance

        require(balance > 0, "MultisigFacet: Insufficient ERC20 balance to confirm");

        l.confirmations[transactionId][msg.sender] = true; // Add confirmation
        l.confirmationSigners[transactionId].push(msg.sender);
        l.confirmationWeights[transactionId][msg.sender] = balance; // Store confirmation weight
        
        emit Confirmation(msg.sender, transactionId);
        
        if (executeIfReady && _isConfirmed(transactionId)) {
            _executeTransaction(transactionId);
        }
    }

    function executeTransaction(uint transactionId)
        public
        transactionExists(transactionId)
        notExecuted(transactionId)
    {        
        _executeTransaction(transactionId);
    }

    function _executeTransaction(uint transactionId) internal virtual{
        if (!_isConfirmed(transactionId)) {
            revert ErrorTxnotConfirmed(transactionId);
        }
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

    function _isConfirmed(uint transactionId) internal view returns (bool) {
        LibMultisigStorage.Layout storage l = LibMultisigStorage.layout();
        uint256 totalWeight = 0;
        uint256 totalSupply = IERC20(l.erc20Address).totalSupply(); // Get total supply of ERC20 tokens
        
        for (uint i = 0; i < l.confirmationSigners[transactionId].length ; i++) {
            address owner = l.confirmationSigners[transactionId][i]; // Assuming owners are stored in the layout
            if (l.confirmations[transactionId][owner]) {
                totalWeight += l.confirmationWeights[transactionId][owner]; // Sum confirmation weights
            }
        }

        // Check if the total confirmed weight percentage meets the required threshold
        return (totalSupply > 0 && (totalWeight * 100) / totalSupply >= l.required);
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
    function getSigners(uint transactionId) external view returns (address[] memory) {
        return LibMultisigStorage.layout().confirmationSigners[transactionId];
    }

    function getErc20Address() external view returns (address) {
        return LibMultisigStorage.layout().erc20Address;
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