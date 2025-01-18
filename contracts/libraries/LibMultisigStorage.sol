// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LibMultisigStorage {
    struct Layout {
        mapping(uint => Transaction) transactions;
        mapping(uint => mapping(address => bool)) confirmations;
        mapping(uint => mapping(address => uint256)) confirmationWeights;
        mapping(uint => address[]) confirmationSigners;
        address erc20Address;
        uint required;
        uint transactionCount;
    }

    struct Transaction {
        address destination;
        uint value;
        bytes data;
        bool executed;
    }

    bytes32 internal constant STORAGE_SLOT = keccak256("diamond.standard.multisig.storage");

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}