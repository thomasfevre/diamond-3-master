// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IDiamondCut.sol";

library LibDiamondCutStorage {
    struct DiamondCutProposalMetadata {
        address _init;
        bytes _initCalldata;
        string _label;
        bool _executed;
    }

    struct Layout {
        mapping(uint => address[]) facetAddresses; // Facet addresses for each proposal
        mapping(uint => uint8[]) actions;          // Actions for each proposal
        mapping(uint => bytes[]) functionSelectorsData; // Encoded function selectors
        mapping(uint => DiamondCutProposalMetadata) proposals; // Metadata for each proposal
        uint proposalCount; // Counter for proposals
    }

    bytes32 internal constant STORAGE_SLOT = keccak256("diamond.standard.diamondcut.proposal.storage");

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }

    // Helper function to encode function selectors
    function encodeFunctionSelectors(bytes4[] memory selectors) internal pure returns (bytes memory) {
        return abi.encode(selectors);
    }

    // Helper function to decode function selectors
    function decodeFunctionSelectors(bytes memory selectorsData) internal pure returns (bytes4[] memory) {
        return abi.decode(selectorsData, (bytes4[]));
    }
}
