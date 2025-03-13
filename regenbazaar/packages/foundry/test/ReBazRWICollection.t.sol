// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../contracts/ReBazRWICollection.sol";

contract ReBazRWICollectionTest is Test {
    ReBazRWICollection collection;
    address creator = address(0x1);
    address regenBazaar = address(0x2);
    address user1 = address(0x3);
    address user2 = address(0x4);

    // Test constants
    string NAME = "ReBaz RWI Collection";
    string SYMBOL = "RBZRWI";
    string BASE_URI = "ipfs://some-cid/";
    
    // RWI data
    string organizationType = "Non-profit";
    string entityName = "EcoRestore";
    string actionTitle = "Forest Restoration Project";
    string achievedImpact = "Planted 5000 trees";
    string timePeriod = "2023-2024";
    string areaOfImpact = "Amazon Rainforest";
    string proofUrl = "ipfs://proof-cid";
    string technicalSkillLevel = "Medium";
    
    // Tier data
    uint256[] tierIds = [1, 2, 3];
    string[] tierNames = ["Bronze", "Silver", "Gold"];
    uint256[] tierPrices = [0.1 ether, 0.5 ether, 1 ether];
    uint256[] tierMaxSupplies = [100, 50, 10];

    function setUp() public {
        vm.deal(creator, 10 ether);
        vm.deal(regenBazaar, 10 ether);
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        
        // Deploy the collection contract
        collection = new ReBazRWICollection(
            NAME,
            SYMBOL,
            creator,
            regenBazaar,
            organizationType,
            entityName,
            actionTitle,
            achievedImpact,
            timePeriod,
            areaOfImpact,
            proofUrl,
            technicalSkillLevel,
            BASE_URI,
            tierIds,
            tierNames,
            tierPrices,
            tierMaxSupplies
        );
    }

    // Test initialization and constructor
    function testInitialization() public {
        // Check name and symbol
        assertEq(collection.name(), NAME);
        assertEq(collection.symbol(), SYMBOL);
        
        // Check creator and regenBazaar addresses
        assertEq(collection.creator(), creator);
        assertEq(collection.regenBazaar(), regenBazaar);
        
        // Check tier information
        for (uint256 i = 0; i < tierIds.length; i++) {
            (string memory name, uint256 price, uint256 maxSupply, uint256 minted) = collection.tiers(tierIds[i]);
            assertEq(name, tierNames[i]);
            assertEq(price, tierPrices[i]);
            assertEq(maxSupply, tierMaxSupplies[i]);
            assertEq(minted, 0);
        }
        
        // Check RWI data
        (
            string memory rwiOrgType,
            string memory rwiEntityName,
            string memory rwiActionTitle,
            string memory rwiAchievedImpact,
            string memory rwiTimePeriod,
            string memory rwiAreaOfImpact,
            string memory rwiProofUrl,
            string memory rwiSkillLevel
        ) = collection.rwiData();
        
        assertEq(rwiOrgType, organizationType);
        assertEq(rwiEntityName, entityName);
        assertEq(rwiActionTitle, actionTitle);
        assertEq(rwiAchievedImpact, achievedImpact);
        assertEq(rwiTimePeriod, timePeriod);
        assertEq(rwiAreaOfImpact, areaOfImpact);
        assertEq(rwiProofUrl, proofUrl);
        assertEq(rwiSkillLevel, technicalSkillLevel);
    }

    // Test minting functionality
    function testMint() public {
        uint256 tierId = 1; // Bronze tier
        uint256 price = 0.1 ether;
        
        // Initial balances
        uint256 initialCreatorBalance = creator.balance;
        uint256 initialRegenBalance = regenBazaar.balance;
        
        // Mint a token as user1
        vm.prank(user1);
        collection.mint{value: price}(tierId);
        
        // Check token ownership
        assertEq(collection.ownerOf(1), user1);
        assertEq(collection.tokenTier(1), tierId);
        
        // Check tier minted count was updated
        (,, uint256 maxSupply, uint256 minted) = collection.tiers(tierId);
        assertEq(minted, 1);
        
        // Check payment distribution (90% to creator, 10% to regenBazaar)
        uint256 creatorShare = (price * 90) / 100;
        uint256 regenShare = price - creatorShare;
        assertEq(creator.balance, initialCreatorBalance + creatorShare);
        assertEq(regenBazaar.balance, initialRegenBalance + regenShare);
    }

    // Test minting multiple tokens
    function testMultipleMints() public {
        // Mint from tier 1 (Bronze)
        vm.prank(user1);
        collection.mint{value: 0.1 ether}(1);
        
        // Mint from tier 2 (Silver)
        vm.prank(user2);
        collection.mint{value: 0.5 ether}(2);
        
        // Check token ownership and tier assignments
        assertEq(collection.ownerOf(1), user1);
        assertEq(collection.tokenTier(1), 1);
        
        assertEq(collection.ownerOf(2), user2);
        assertEq(collection.tokenTier(2), 2);
        
        // Check current token ID
        assertEq(collection.currentTokenId(), 2);
        
        // Check tier minted counts
        (,, , uint256 minted1) = collection.tiers(1);
        (,, , uint256 minted2) = collection.tiers(2);
        assertEq(minted1, 1);
        assertEq(minted2, 1);
    }

    // Test tier sold out
    function testTierSoldOut() public {
        uint256 tierId = 3; // Gold tier with max supply of 10
        
        // Mint all available tokens in this tier
        for (uint256 i = 0; i < 10; i++) {
            vm.prank(user1);
            collection.mint{value: 1 ether}(tierId);
        }
        
        // Try to mint one more, should revert
        vm.prank(user1);
        vm.expectRevert("Tier sold out");
        collection.mint{value: 1 ether}(tierId);
    }

    // Test incorrect payment amount
    function testIncorrectPayment() public {
        uint256 tierId = 1; // Bronze tier (0.1 ether)
        
        // Send incorrect amount (too little)
        vm.prank(user1);
        vm.expectRevert("Incorrect Ether value sent");
        collection.mint{value: 0.05 ether}(tierId);
        
        // Send incorrect amount (too much)
        vm.prank(user1);
        vm.expectRevert("Incorrect Ether value sent");
        collection.mint{value: 0.2 ether}(tierId);
    }

    // Test non-existent tier
    function testNonExistentTier() public {
        uint256 nonExistentTierId = 99;
        
        vm.prank(user1);
        vm.expectRevert("Tier does not exist");
        collection.mint{value: 1 ether}(nonExistentTierId);
    }

    // Test base URI functionality
    function testTokenURI() public {
        // Mint a token first
        vm.prank(user1);
        collection.mint{value: 0.1 ether}(1);
        
        // Check the token URI
        string memory expectedURI = string(abi.encodePacked(BASE_URI, "1"));
        assertEq(collection.tokenURI(1), expectedURI);
        
        // Change the base URI
        string memory newBaseURI = "https://new-metadata.com/";
        vm.prank(collection.owner());
        collection.setBaseURI(newBaseURI);
        
        // Check the updated token URI
        string memory newExpectedURI = string(abi.encodePacked(newBaseURI, "1"));
        assertEq(collection.tokenURI(1), newExpectedURI);
    }

    // Test royalty info
    function testRoyaltyInfo() public {
        // Mint a token first
        vm.prank(user1);
        collection.mint{value: 0.1 ether}(1);
        
        // Check royalty info for token 1 at sale price of 1 ether
        (address receiver, uint256 royaltyAmount) = collection.royaltyInfo(1, 1 ether);
        
        // Royalty should be 10% (1000 basis points)
        assertEq(royaltyAmount, 0.1 ether);
        
        // Receiver should be the royalty splitter contract
        assertEq(receiver, address(collection.royaltySplitter()));
    }

    // Test ERC165 interface support
    function testSupportsInterface() public {
        // ERC721 interface ID
        bytes4 erc721InterfaceId = 0x80ac58cd;
        // ERC2981 Royalty Standard interface ID
        bytes4 erc2981InterfaceId = 0x2a55205a;
        
        assertTrue(collection.supportsInterface(erc721InterfaceId));
        assertTrue(collection.supportsInterface(erc2981InterfaceId));
    }

    // Test unauthorized base URI change
    function testUnauthorizedBaseURIChange() public {
        vm.prank(user1); // user1 is not the owner
        vm.expectRevert("Ownable: caller is not the owner");
        collection.setBaseURI("https://attacker.com/");
    }
}