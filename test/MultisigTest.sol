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

contract MultisigTest is Test {
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
    address testDestination;
    address zeroAddress = address(0);

    function setUp() public {
        owner = address(this);
        owner1 = makeAddr("owner1");
        owner2 = makeAddr("owner2");
        owner3 = makeAddr("owner3");
        nonOwner = makeAddr("nonOwner");
        testDestination = makeAddr("testDestination");
        
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
        diamond = new Diamond(diamondCut, diamondArgs);

        // Initialize Multisig
        multisigFacet = MultisigFacet(address(diamond));
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
    function getDiamondCutFacetSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = DiamondCutFacet.diamondCut.selector;
        return selectors;
    }

    function getDiamondLoupeFacetSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = DiamondLoupeFacet.facetAddresses.selector;
        selectors[1] = DiamondLoupeFacet.facetAddress.selector;
        selectors[2] = DiamondLoupeFacet.facets.selector;
        return selectors;
    }

    function getMultisigFacetSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = MultisigFacet.initializeMultisig.selector;
        selectors[1] = MultisigFacet.submitTransaction.selector;
        selectors[2] = MultisigFacet.confirmTransaction.selector;
        selectors[3] = MultisigFacet.executeTransaction.selector;
        selectors[4] = MultisigFacet.getOwners.selector;
        selectors[5] = MultisigFacet.getTransactionCount.selector;
        return selectors;
    }

    // Existing test functions will follow...
    function testInitialFacets() public view {
        IDiamondLoupe diamondLoupe = IDiamondLoupe(address(diamond));
        address[] memory facetAddresses = diamondLoupe.facetAddresses();
        assertEq(facetAddresses.length, 3);
    }

    // Rest of the test functions from previous implementation...
    function testInitializeMultisig() public view {
        address[] memory owners = multisigFacet.getOwners();
        assertEq(owners.length, 3);
        assertEq(owners[0], owner1);
        assertEq(owners[1], owner2);
        assertEq(owners[2], owner3);
    }

    function testSubmitTransaction() public {
        vm.prank(owner1);
        uint txId = multisigFacet.submitTransaction(testDestination, 0.1 ether, "");

        // Ensure transaction was submitted
        assertEq(multisigFacet.getTransactionCount(true, false), 1);
    }

    function testConfirmTransaction() public {
        // Submit transaction
        vm.prank(owner1);
        uint txId = multisigFacet.submitTransaction(testDestination, 0.1 ether, "");

        // Confirm by second owner
        vm.prank(owner2);
        multisigFacet.confirmTransaction(txId, false);

        // Transaction should be executed with 2 confirmations
        assertEq(multisigFacet.getTransactionCount(true, false), 1);
    }

    function testCannotSubmitTransactionAsNonOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert("MultisigFacet: Owner does not exist");
        multisigFacet.submitTransaction(testDestination, 0.1 ether, "");
    }

    function testCannotConfirmTransactionTwice() public {
        // Submit transaction
        vm.prank(owner1);
        uint txId = multisigFacet.submitTransaction(testDestination, 0.1 ether, "");

        // Confirm by first owner
        vm.prank(owner1);
        vm.expectRevert("MultisigFacet: Already confirmed");
        multisigFacet.confirmTransaction(txId, false);
    }

    function testTransactionRequiresMultipleConfirmations() public {
        // Submit transaction
        vm.prank(owner1);
        uint txId = multisigFacet.submitTransaction(testDestination, 0.1 ether, "");

        // Only one confirmation, should not execute
        assertEq(multisigFacet.getTransactionCount(true, false), 1);
        assertEq(multisigFacet.getTransactionCount(false, true), 0);

        vm.prank(owner2);
        multisigFacet.confirmTransaction(txId, false);

       
       // add ethers to the diamond
       vm.deal(address(diamond), 1 ether);
       //execute transaction
       vm.prank(owner1);
       multisigFacet.executeTransaction(txId);

        // Transaction should be executed with 2 confirmations
        assertEq(multisigFacet.getTransactionCount(true, false), 0);
        assertEq(multisigFacet.getTransactionCount(false, true), 1);
    }

    // Additional tests can be added to cover more scenarios
}