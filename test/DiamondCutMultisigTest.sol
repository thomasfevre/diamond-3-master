// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../contracts/Diamond.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/MultisigFacet.sol";
import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/interfaces/IDiamondLoupe.sol";

 // Test Facet for adding during tests
contract TestFacet {
    function testFunction() public view returns (bool) {
        return true;
    }
}

contract DiamondCutMultisigTest is Test {
    Diamond diamond;
    DiamondCutFacet diamondCutFacet;
    DiamondLoupeFacet diamondLoupeFacet;
    OwnershipFacet ownershipFacet;
    MultisigFacet multisigFacet;
    
    address owner;
    address owner1;
    address owner2;
    address owner3;
    address nonOwner;
    address zeroAddress = address(0);

   

    function setUp() public {
        owner = address(this);
        owner1 = makeAddr("owner1");
        owner2 = makeAddr("owner2");
        owner3 = makeAddr("owner3");
        nonOwner = makeAddr("nonOwner");
        
        // Deploy facets
        diamondCutFacet = new DiamondCutFacet();
        diamondLoupeFacet = new DiamondLoupeFacet();
        ownershipFacet = new OwnershipFacet();
        multisigFacet = new MultisigFacet();

        // Initialize Diamond arguments
        Diamond.DiamondArgs memory diamondArgs = Diamond.DiamondArgs({
            owner: owner
        });

        // Create FacetCut array for initialization
        IDiamondCut.FacetCut[] memory diamondCut = new IDiamondCut.FacetCut[](3);
        
        // DiamondCutFacet
        bytes4[] memory cutSelectors = getDiamondCutFacetSelectors();
        diamondCut[0] = IDiamondCut.FacetCut({
            facetAddress: address(diamondCutFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: cutSelectors
        });

        // DiamondLoupeFacet
        bytes4[] memory loupeSelectors = getDiamondLoupeFacetSelectors();
        diamondCut[1] = IDiamondCut.FacetCut({
            facetAddress: address(diamondLoupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: loupeSelectors
        });

        // MultisigFacet
        bytes4[] memory multisigSelectors = getMultisigFacetSelectors();
        diamondCut[2] = IDiamondCut.FacetCut({
            facetAddress: address(multisigFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: multisigSelectors
        });

        // Initialize Diamond
        diamond = new Diamond(diamondCut);

        // Initialize Multisig
        multisigFacet = MultisigFacet(address(diamond));
        diamondCutFacet = DiamondCutFacet(address(diamond));
        diamondLoupeFacet = DiamondLoupeFacet(address(diamond));
        multisigFacet.initializeMultisig(
            getInitialOwners(), 
            2  // Required confirmations
        );
    }

    function getInitialOwners() internal view returns (address[] memory) {
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;
        return owners;
    }

    // Helper functions to get selectors
    function getDiamondCutFacetSelectors() internal view returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = diamondCutFacet.submitDiamondCutProposal.selector;
        selectors[1] = diamondCutFacet.getDiamondCutProposal.selector;
        selectors[2] = diamondCutFacet.executeDiamondCutProposal.selector;
        selectors[3] = diamondCutFacet.diamondCut.selector;
        return selectors;
    }

    function getDiamondLoupeFacetSelectors() internal view returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = diamondLoupeFacet.facetAddresses.selector;
        selectors[1] = diamondLoupeFacet.facetAddress.selector;
        selectors[2] = diamondLoupeFacet.facets.selector;
        return selectors;
    }

    function getMultisigFacetSelectors() internal view returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = multisigFacet.initializeMultisig.selector;
        selectors[1] = multisigFacet.submitTransaction.selector;
        selectors[2] = multisigFacet.confirmTransaction.selector;
        selectors[3] = multisigFacet.executeTransaction.selector;
        selectors[4] = multisigFacet.getOwners.selector;
        selectors[5] = multisigFacet.getTransactionCount.selector;
        return selectors;
    }

    function testSubmitDiamondCutProposal() public {
        // Deploy a test facet
        TestFacet testFacet = new TestFacet();
        
        // Prepare facet cut
        IDiamondCut.FacetCut[] memory facetCuts = new IDiamondCut.FacetCut[](1);
        bytes4[] memory testSelectors = new bytes4[](1);
        testSelectors[0] = TestFacet.testFunction.selector;
        
        facetCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(testFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: testSelectors
        });

        // Submit proposal as owner1
        vm.prank(owner1);
        uint proposalId = diamondCutFacet.submitDiamondCutProposal(
            facetCuts, 
            address(0), 
            "", 
            "Test Facet Addition"
        );

        // Verify proposal details
        (
            IDiamondCut.FacetCut[] memory retrievedCuts, 
            address init, 
            bytes memory initCalldata, 
            string memory label,
            bool executed
        ) = diamondCutFacet.getDiamondCutProposal(proposalId);

        assertEq(retrievedCuts.length, 1);
        assertEq(retrievedCuts[0].facetAddress, address(testFacet));
        assertEq(label, "Test Facet Addition");
        assertFalse(executed);
    }

    function testExecuteDiamondCutProposal() public {
        // Deploy a test facet
        TestFacet testFacet = new TestFacet();
        
        // Prepare facet cut
        IDiamondCut.FacetCut[] memory facetCuts = new IDiamondCut.FacetCut[](1);
        bytes4[] memory testSelectors = new bytes4[](1);
        testSelectors[0] = TestFacet.testFunction.selector;
        
        facetCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(testFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: testSelectors
        });

        // Submit proposal as owner1
        vm.prank(owner1);
        uint proposalId = diamondCutFacet.submitDiamondCutProposal(
            facetCuts, 
            address(0), 
            "", 
            "Test Facet Addition"
        );

        // Confirm by owner2
        vm.prank(owner2);
        multisigFacet.confirmTransaction(proposalId, false);

        // Execute proposal as owner1
        vm.prank(owner1);
        diamondCutFacet.executeDiamondCutProposal(proposalId);

        // Verify facet was added
        IDiamondLoupe diamondLoupe = IDiamondLoupe(address(diamond));
        address[] memory facetAddresses = diamondLoupe.facetAddresses();
        assertEq(facetAddresses.length, 4);  // Original 3 + new test facet
    }

    function testCannotExecuteDiamondCutProposalWithoutConfirmations() public {
        // Deploy a test facet
        TestFacet testFacet = new TestFacet();
        
        // Prepare facet cut
        IDiamondCut.FacetCut[] memory facetCuts = new IDiamondCut.FacetCut[](1);
        bytes4[] memory testSelectors = new bytes4[](1);
        testSelectors[0] = TestFacet.testFunction.selector;
        
        facetCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(testFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: testSelectors
        });

        // Submit proposal as owner1
        vm.prank(owner1);
        uint proposalId = diamondCutFacet.submitDiamondCutProposal(
            facetCuts, 
            address(0), 
            "", 
            "Test Facet Addition"
        );

        // Attempt to execute without sufficient confirmations
        vm.prank(owner1);
        vm.expectRevert(abi.encodeWithSignature("ErrorTxnotConfirmed(uint256)", 0));
        diamondCutFacet.executeDiamondCutProposal(proposalId);
    }

    function testCannotExecuteDiamondCutProposalTwice() public {
        // Deploy a test facet
        TestFacet testFacet = new TestFacet();
        
        // Prepare facet cut
        IDiamondCut.FacetCut[] memory facetCuts = new IDiamondCut.FacetCut[](1);
        bytes4[] memory testSelectors = new bytes4[](1);
        testSelectors[0] = TestFacet.testFunction.selector;
        
        facetCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(testFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: testSelectors
        });

        // Submit proposal as owner1
        vm.prank(owner1);
        uint proposalId = diamondCutFacet.submitDiamondCutProposal(
            facetCuts, 
            address(0), 
            "", 
            "Test Facet Addition"
        );

        // Confirm by owner2
        vm.prank(owner2);
        multisigFacet.confirmTransaction(proposalId, false);

        // Execute proposal as owner1
        vm.prank(owner1);
        diamondCutFacet.executeDiamondCutProposal(proposalId);

        // Attempt to execute again
        vm.prank(owner1);
        vm.expectRevert("DiamondCutFacet: Proposal already executed");
        diamondCutFacet.executeDiamondCutProposal(proposalId);
    }
}