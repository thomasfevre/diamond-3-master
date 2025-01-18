// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "../interfaces/IDiamondCut.sol";
import "../libraries/LibDiamond.sol";
import "./MultisigFacet.sol";
import "../libraries/LibDiamondCutStorage.sol";
import "../libraries/LibMultisigStorage.sol";

contract DiamondCutFacet is MultisigFacet {
    event DiamondCutProposalSubmitted(uint indexed proposalId, string label);
    event DiamondCutProposalExecuted(uint indexed proposalId, string label);

     /// @notice Add/replace/remove any number of functions and optionally execute
    ///         a function with delegatecall
    /// @param _diamondCut Contains the facet addresses and function selectors
    /// @param _init The address of the contract or facet to execute _calldata
    /// @param _calldata A function call, including function selector and arguments
    ///                  _calldata is executed with delegatecall on _init
    function diamondCut(
        IDiamondCut.FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.diamondCut(_diamondCut, _init, _calldata);
    }

    function submitDiamondCutProposal(
        IDiamondCut.FacetCut[] memory _facetCuts,
        address _init,
        bytes memory _initCalldata,
        string memory _label
    ) public returns (uint proposalId) {
        // Submit transaction via MultisigFacet
        proposalId = submitTransaction(
            address(this),
            0,
            abi.encodeWithSelector(
                IDiamondCut.diamondCut.selector,
                _facetCuts,
                _init,
                _initCalldata
            )
        );

        // Store additional Diamond Cut proposal details
        LibDiamondCutStorage.Layout storage l = LibDiamondCutStorage.layout();

        // Initialize metadata separately to reduce stack usage
        l.proposals[proposalId] = LibDiamondCutStorage.DiamondCutProposalMetadata({
            _init: _init,
            _initCalldata: _initCalldata,
            _label: _label,
            _executed: false
        });

        _storeFacetCuts(proposalId, _facetCuts);

        emit DiamondCutProposalSubmitted(proposalId, _label);
    }

    function _storeFacetCuts(uint proposalId, IDiamondCut.FacetCut[] memory _facetCuts) internal {
        LibDiamondCutStorage.Layout storage l = LibDiamondCutStorage.layout();

        // Prepare storage-friendly arrays
        for (uint i = 0; i < _facetCuts.length; i++) {
            l.facetAddresses[proposalId].push(_facetCuts[i].facetAddress);
            l.actions[proposalId].push(uint8(_facetCuts[i].action));
            l.functionSelectorsData[proposalId].push(
                LibDiamondCutStorage.encodeFunctionSelectors(_facetCuts[i].functionSelectors)
            );
        }
    }

    function getDiamondCutProposal(uint proposalId)
        public
        view
        returns (
            IDiamondCut.FacetCut[] memory facetCuts,
            address init,
            bytes memory initCalldata,
            string memory label,
            bool executed
        )
    {
        LibDiamondCutStorage.Layout storage l = LibDiamondCutStorage.layout();
        LibDiamondCutStorage.DiamondCutProposalMetadata storage metadata = l.proposals[proposalId];

        // Reconstruct FacetCuts
        facetCuts = new IDiamondCut.FacetCut[](l.facetAddresses[proposalId].length);
        for (uint i = 0; i < l.facetAddresses[proposalId].length; i++) {
            facetCuts[i] = IDiamondCut.FacetCut({
                facetAddress: l.facetAddresses[proposalId][i],
                action: IDiamondCut.FacetCutAction(l.actions[proposalId][i]),
                functionSelectors: LibDiamondCutStorage.decodeFunctionSelectors(
                    l.functionSelectorsData[proposalId][i]
                )
            });
        }

        return (
            facetCuts,
            metadata._init,
            metadata._initCalldata,
            metadata._label,
            metadata._executed
        );
    }

    function executeDiamondCutProposal(uint proposalId)
        public
    {
        LibDiamondCutStorage.Layout storage l = LibDiamondCutStorage.layout();
        LibDiamondCutStorage.DiamondCutProposalMetadata storage metadata = l.proposals[proposalId];

        require(!metadata._executed, "DiamondCutFacet: Proposal already executed");

        // Execute the transaction (this will call the Diamond's diamondCut function)
        executeTransaction(proposalId);

        // Mark proposal as executed
        metadata._executed = true;

        emit DiamondCutProposalExecuted(proposalId, metadata._label);
    }
}
