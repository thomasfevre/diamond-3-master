// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../contracts/Diamond.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/interfaces/IDiamondLoupe.sol";

struct DiamondArgs {
    address owner;
}

contract DiamondTest is Test {
    Diamond diamond;
    DiamondCutFacet diamondCutFacet;
    DiamondLoupeFacet diamondLoupeFacet;
    OwnershipFacet ownershipFacet;
    
    address owner;
    address zeroAddress = address(0);

    enum FacetCutAction {Add, Replace, Remove}

    function setUp() public {
        owner = address(this);
        
        // Deploy facets
        diamondCutFacet = new DiamondCutFacet();
        diamondLoupeFacet = new DiamondLoupeFacet();
        ownershipFacet = new OwnershipFacet();
      

        // Initialize Diamond arguments
        Diamond.DiamondArgs memory diamondArgs = Diamond.DiamondArgs({
            owner: owner
        });

        // Create FacetCut array for initialization
        IDiamondCut.FacetCut[] memory diamondCut = new IDiamondCut.FacetCut[](2);
        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = IDiamondCut.diamondCut.selector;
        
        diamondCut[0] = IDiamondCut.FacetCut({
            facetAddress: address(diamondCutFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });

        bytes4[] memory loupeSelectors = getDiamondLoupeFacetSelectors();
        diamondCut[1] = IDiamondCut.FacetCut({
            facetAddress: address(diamondLoupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: loupeSelectors
        });

        // Initialize Diamond
        diamond = new Diamond(diamondCut, diamondArgs);
    }

    function testInitialFacets() public view {
        IDiamondLoupe diamondLoupe = IDiamondLoupe(address(diamond));
        address[] memory facetAddresses = diamondLoupe.facetAddresses();
        assertEq(facetAddresses.length, 2);
    }

    // function testFacetSelectors() public {
    //     // Test DiamondCutFacet selectors
    //     bytes4[] memory cutSelectors = getDiamondCutFacetSelectors();
    //     assertEq(diamondLoupeFacet.facetFunctionSelectors(address(diamondCutFacet)), cutSelectors);

    //     // Test DiamondLoupeFacet selectors
    //     bytes4[] memory loupeSelectors = getDiamondLoupeFacetSelectors();
    //     assertEq(diamondLoupeFacet.facetFunctionSelectors(address(diamondLoupeFacet)), loupeSelectors);

    //     // Test OwnershipFacet selectors
    //     bytes4[] memory ownershipSelectors = getOwnershipFacetSelectors();
    //     assertEq(diamondLoupeFacet.facetFunctionSelectors(address(ownershipFacet)), ownershipSelectors);
    // }


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

    function getOwnershipFacetSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = OwnershipFacet.transferOwnership.selector;
        return selectors;
    }
}