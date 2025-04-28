// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/factory/ImpactProductFactory.sol";
import "../contracts/tokens/ImpactProductNFT.sol";
import "../contracts/interfaces/IImpactProductNFT.sol";

contract ImpactProductFactoryTest is Test {
    ImpactProductNFT nft;
    ImpactProductFactory factory;
    
    address admin = address(1);
    address creator = address(2);
    address verifier = address(3);
    address user1 = address(4);
    address platformWallet = address(5);
    
    string baseTokenURI = "https://api.regenbazaar.com/metadata/";

    event ImpactProductCreated(
        uint256 indexed tokenId, 
        address indexed creator, 
        string category,
        uint256 impactValue,
        uint256 price,
        bool verified
    );

    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy NFT contract
        nft = new ImpactProductNFT(platformWallet, baseTokenURI);
        
        // Deploy factory
        factory = new ImpactProductFactory(address(nft), platformWallet);
        
        // Grant permissions
        nft.grantRole(nft.MINTER_ROLE(), address(factory));
        nft.grantRole(nft.VERIFIER_ROLE(), address(factory));
        
        factory.grantCreatorRole(creator);
        factory.grantRole(factory.VERIFIER_ROLE(), verifier);
        
        vm.stopPrank();
    }

    // Basic Functionality Tests
    function testDeployment() public view {
        assertTrue(factory.hasRole(factory.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(factory.hasRole(factory.CREATOR_ROLE(), creator));
        assertTrue(factory.hasRole(factory.VERIFIER_ROLE(), verifier));
        assertEq(factory.platformFeeReceiver(), platformWallet);
        
        // Check that default categories were created
        string[] memory categories = factory.getSupportedCategories();
        assertGt(categories.length, 0);
    }

    function testCreateProductThroughFactory() public {
        string memory category = "Tree preservation";
        string memory location = "Amazon Rainforest";
        uint256 startDate = block.timestamp - 30 days;
        uint256 endDate = block.timestamp + 365 days;
        string memory beneficiaries = "Local communities";
        uint256 baseImpactValue = 1000;
        uint256 listingPrice = 1 ether;
        string memory metadataURI = "ipfs://QmHash";
        
        vm.prank(creator);
        vm.expectEmit(true, true, false, true);
        emit ImpactProductCreated(0, creator, category, 0, listingPrice, false);
        uint256 tokenId = factory.createImpactProduct(
            category,
            location,
            startDate,
            endDate,
            beneficiaries,
            baseImpactValue,
            listingPrice,
            metadataURI
        );
        
        assertEq(tokenId, 0);
        assertEq(nft.ownerOf(tokenId), creator);
        
        // Check impact data
        ImpactProductNFT.ImpactData memory impactData = nft.getImpactData(tokenId);
        assertEq(impactData.category, category);
        assertEq(impactData.location, location);
        assertEq(impactData.startDate, startDate);
        assertEq(impactData.endDate, endDate);
        assertEq(impactData.beneficiaries, beneficiaries);
        assertFalse(impactData.verified);
        
        // Check that impact value was calculated with multiplier
        assertGt(impactData.impactValue, baseImpactValue);
    }

    function testImpactCalculation() public  view {
        // Test calculation for a specific category
        string memory category = "Tree preservation";
        uint256 baseValue = 1000;
        
        uint256 calculatedValue = factory.calculateImpactValue(category, baseValue);
        
        // Calculation should multiply baseValue by category multiplier
        // The Tree preservation category has a 2500 bps (25%) multiplier
        assertEq(calculatedValue, (baseValue * 2500) / 10000);
    }

    function testCategoryManagement() public {
        // Add a new category
        string memory newCategory = "Water Conservation";
        uint256 multiplier = 2000;
        
        vm.prank(admin);
        factory.addImpactCategory(newCategory, multiplier);
        
        // Verify category was added
        string[] memory categories = factory.getSupportedCategories();
        bool found = false;
        for (uint256 i = 0; i < categories.length; i++) {
            if (keccak256(bytes(categories[i])) == keccak256(bytes(newCategory))) {
                found = true;
                break;
            }
        }
        assertTrue(found);
        
        // Test category works for impact calculation
        uint256 calculatedValue = factory.calculateImpactValue(newCategory, 1000);
        assertEq(calculatedValue, (1000 * multiplier) / 10000);
        
        // Remove the category
        vm.prank(admin);
        factory.removeImpactCategory(newCategory);
        
        // Verify it was removed
        categories = factory.getSupportedCategories();
        found = false;
        for (uint256 i = 0; i < categories.length; i++) {
            if (keccak256(bytes(categories[i])) == keccak256(bytes(newCategory))) {
                found = true;
                break;
            }
        }
        assertFalse(found);
    }
    
    // Access Control Tests
    function testOnlyCreatorsCanCreate() public {
        string memory category = "Tree preservation";
        string memory location = "Amazon Rainforest";
        uint256 startDate = block.timestamp - 30 days;
        uint256 endDate = block.timestamp + 365 days;
        string memory beneficiaries = "Local communities";
        uint256 baseImpactValue = 1000;
        uint256 listingPrice = 1 ether;
        string memory metadataURI = "ipfs://QmHash";
        
        // Non-creator tries to create a product
        vm.prank(user1);
        vm.expectRevert();
        factory.createImpactProduct(
            category,
            location,
            startDate,
            endDate,
            beneficiaries,
            baseImpactValue,
            listingPrice,
            metadataURI
        );
        
        // Admin grants creator role to user1
        vm.prank(admin);
        factory.grantCreatorRole(user1);
        
        // Now user1 should be able to create
        vm.prank(user1);
        uint256 tokenId = factory.createImpactProduct(
            category,
            location,
            startDate,
            endDate,
            beneficiaries,
            baseImpactValue,
            listingPrice,
            metadataURI
        );
        
        assertEq(nft.ownerOf(tokenId), user1);
    }

    function testOnlyAdminsCanManageCategories() public {
        string memory newCategory = "Water Conservation";
        uint256 multiplier = 2000;
        
        // Non-admin tries to add a category
        vm.prank(user1);
        vm.expectRevert();
        factory.addImpactCategory(newCategory, multiplier);
        
        // Non-admin tries to remove an existing category
        vm.prank(user1);
        vm.expectRevert();
        factory.removeImpactCategory("Tree preservation");
        
        // Non-admin tries to update parameters
        vm.prank(user1);
        vm.expectRevert();
        factory.updateImpactParams("Tree preservation", 3000);
    }

    function testRoleAssignment() public {
        vm.prank(admin);
        factory.grantCreatorRole(user1);
        assertTrue(factory.hasRole(factory.CREATOR_ROLE(), user1));
        
        vm.prank(admin);
        factory.revokeCreatorRole(user1);
        assertFalse(factory.hasRole(factory.CREATOR_ROLE(), user1));
    }

    // Edge Cases
    function testUnsupportedCategory() public {
        string memory nonExistentCategory = "Non-existent Category";
        string memory location = "Amazon Rainforest";
        uint256 startDate = block.timestamp - 30 days;
        uint256 endDate = block.timestamp + 365 days;
        string memory beneficiaries = "Local communities";
        uint256 baseImpactValue = 1000;
        uint256 listingPrice = 1 ether;
        string memory metadataURI = "ipfs://QmHash";
        
        vm.prank(creator);
        vm.expectRevert();
        factory.createImpactProduct(
            nonExistentCategory,
            location,
            startDate,
            endDate,
            beneficiaries,
            baseImpactValue,
            listingPrice,
            metadataURI
        );
    }

    function testDuplicateCategories() public {
        string memory category = "Tree preservation"; // Already exists
        uint256 multiplier = 2000;
        
        vm.prank(admin);
        vm.expectRevert();
        factory.addImpactCategory(category, multiplier);
    }

    function testZeroMultiplier() public {
        string memory newCategory = "Water Conservation";
        uint256 zeroMultiplier = 0;
        
        vm.prank(admin);
        vm.expectRevert();
        factory.addImpactCategory(newCategory, zeroMultiplier);
    }

    // Fuzz Testing
    function testFuzzImpactCalculation(uint256 baseValue) public view {
        vm.assume(baseValue > 0 && baseValue < 1_000_000_000);
        
        string memory category = "Tree preservation"; // Has multiplier of 2500 bps
        
        uint256 calculatedValue = factory.calculateImpactValue(category, baseValue);
        assertEq(calculatedValue, (baseValue * 2500) / 10000);
    }
}