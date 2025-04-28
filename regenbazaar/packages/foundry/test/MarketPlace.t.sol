// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/marketplace/MarketPlace.sol";
import "../contracts/tokens/ImpactProductNFT.sol";
import "../contracts/interfaces/IImpactProductNFT.sol";
import "../contracts/interfaces/IMarketPlace.sol";

contract RegenMarketplaceTest is Test {
    RegenMarketplace marketplace;
    ImpactProductNFT nft;
    
    address admin = address(1);
    address operator = address(2);
    address seller = address(3);
    address buyer = address(4);
    address platformWallet = address(5);
    
    string baseTokenURI = "https://api.regenbazaar.com/metadata/";
    uint256 tokenId;
    uint256 price = 1 ether;

    event ProductListed(uint256 indexed tokenId, address indexed seller, uint256 price, uint256 listingTime);
    event ListingUpdated(uint256 indexed tokenId, uint256 newPrice);
    event ListingCanceled(uint256 indexed tokenId, address indexed seller);
    event ProductSold(
        uint256 indexed tokenId, 
        address indexed seller, 
        address indexed buyer, 
        uint256 price, 
        uint256 platformFee,
        uint256 creatorFee
    );

    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy NFT contract
        nft = new ImpactProductNFT(platformWallet, baseTokenURI);
        
        // Deploy marketplace
        marketplace = new RegenMarketplace(address(nft), platformWallet);
        
        // Grant roles
        marketplace.grantRole(marketplace.OPERATOR_ROLE(), operator);
        nft.grantRole(nft.MINTER_ROLE(), admin);
        
        // Create an NFT to use in tests - Using the direct NFT contract struct
        ImpactProductNFT.ImpactData memory impactData;
        impactData.category = "Reforestation";
        impactData.impactValue = 1000;
        impactData.location = "Amazon Rainforest";
        impactData.startDate = block.timestamp - 30 days;
        impactData.endDate = block.timestamp + 365 days;
        impactData.beneficiaries = "Local communities";
        impactData.verified = false;
        impactData.metadataURI = "ipfs://QmHash";
        
        nft.createImpactProduct(seller, impactData, price, seller, 500);
        tokenId = 0;
        
        vm.stopPrank();
    }

    // Basic Listing Functionality
    function testListProduct() public {
        // Approve marketplace to transfer NFT
        vm.prank(seller);
        nft.approve(address(marketplace), tokenId);
        
        // List the NFT
        vm.prank(seller);
        vm.expectEmit(true, true, false, true);
        emit ProductListed(tokenId, seller, price, block.timestamp);
        bool success = marketplace.listProduct(tokenId, price);
        
        assertTrue(success);
        
        // Verify listing
        IRegenMarketplace.Listing memory listing = marketplace.getListing(tokenId);
        assertEq(listing.seller, seller);
        assertEq(listing.tokenId, tokenId);
        assertEq(listing.price, price);
        assertTrue(listing.active);
        assertEq(listing.listingTime, block.timestamp);
        
        // Check listing enumeration
        uint256[] memory activeListings = marketplace.getActiveListings();
        assertEq(activeListings.length, 1);
        assertEq(activeListings[0], tokenId);
        
        uint256[] memory sellerListings = marketplace.getListingsBySeller(seller);
        assertEq(sellerListings.length, 1);
        assertEq(sellerListings[0], tokenId);
    }

    function testUpdateListing() public {
        // First list the product
        vm.prank(seller);
        nft.approve(address(marketplace), tokenId);
        
        vm.prank(seller);
        marketplace.listProduct(tokenId, price);
        
        // Update the price
        uint256 newPrice = 2 ether;
        vm.prank(seller);
        vm.expectEmit(true, false, false, true);
        emit ListingUpdated(tokenId, newPrice);
        bool success = marketplace.updateListing(tokenId, newPrice);
        
        assertTrue(success);
        
        // Verify updated price
        IRegenMarketplace.Listing memory listing = marketplace.getListing(tokenId);
        assertEq(listing.price, newPrice);
    }

    function testCancelListing() public {
        // First list the product
        vm.prank(seller);
        nft.approve(address(marketplace), tokenId);
        
        vm.prank(seller);
        marketplace.listProduct(tokenId, price);
        
        // Cancel the listing
        vm.prank(seller);
        vm.expectEmit(true, true, false, false);
        emit ListingCanceled(tokenId, seller);
        bool success = marketplace.cancelListing(tokenId);
        
        assertTrue(success);
        
        // Verify listing is inactive
        IRegenMarketplace.Listing memory listing = marketplace.getListing(tokenId);
        assertFalse(listing.active);
        
        // Verify it's removed from active listings
        uint256[] memory activeListings = marketplace.getActiveListings();
        assertEq(activeListings.length, 0);
    }

    // Purchase Functionality
    function testBuyProduct() public {
        // First list the product
        vm.prank(seller);
        nft.approve(address(marketplace), tokenId);
        
        vm.prank(seller);
        marketplace.listProduct(tokenId, price);
        
        // Record balances before purchase
        uint256 sellerBalanceBefore = seller.balance;
        uint256 platformBalanceBefore = platformWallet.balance;
        
        // Buy the product
        vm.prank(buyer);
        vm.deal(buyer, price);
        vm.expectEmit(true, true, true, true);
        uint256 platformFee = (price * marketplace.platformFeeBps()) / 10000;
        uint256 royaltyAmount = (price * 500) / 10000; // 5% royalty
        emit ProductSold(tokenId, seller, buyer, price, platformFee, royaltyAmount);
        bool success = marketplace.buyProduct{value: price}(tokenId);
        
        assertTrue(success);
        
        // Verify NFT ownership transferred
        assertEq(nft.ownerOf(tokenId), buyer);
        
        // Verify listing is inactive
        IRegenMarketplace.Listing memory listing = marketplace.getListing(tokenId);
        assertFalse(listing.active);
        
        // Verify payments
        assertEq(platformWallet.balance, platformBalanceBefore + platformFee);
        assertEq(seller.balance, sellerBalanceBefore + price - platformFee - royaltyAmount);
    }

    function testBuyProductWithExcessPayment() public {
        // First list the product
        vm.prank(seller);
        nft.approve(address(marketplace), tokenId);
        
        vm.prank(seller);
        marketplace.listProduct(tokenId, price);
        
        // Buy with excess payment
        uint256 excessPayment = price + 0.5 ether;
        vm.prank(buyer);
        vm.deal(buyer, excessPayment);
        bool success = marketplace.buyProduct{value: excessPayment}(tokenId);
        
        assertTrue(success);
        
        // Verify buyer got refund
        assertEq(buyer.balance, 0.5 ether);
    }

    // Access Control
    function testOnlySellerCanUpdate() public {
        // First list the product
        vm.prank(seller);
        nft.approve(address(marketplace), tokenId);
        
        vm.prank(seller);
        marketplace.listProduct(tokenId, price);
        
        // Non-seller tries to update
        vm.prank(buyer);
        vm.expectRevert();
        marketplace.updateListing(tokenId, 2 ether);
    }

    function testOnlySellerOrAdminCanCancel() public {
        // First list the product
        vm.prank(seller);
        nft.approve(address(marketplace), tokenId);
        
        vm.prank(seller);
        marketplace.listProduct(tokenId, price);
        
        // Non-seller, non-admin tries to cancel
        vm.prank(buyer);
        vm.expectRevert();
        marketplace.cancelListing(tokenId);
        
        // Admin can cancel
        vm.prank(admin);
        bool success = marketplace.cancelListing(tokenId);
        assertTrue(success);
    }

    // Edge Cases
    function testBuyUnlistedProduct() public {
        vm.prank(buyer);
        vm.deal(buyer, price);
        vm.expectRevert();
        marketplace.buyProduct{value: price}(tokenId);
    }

    function testBuyOwnProduct() public {
        // First list the product
        vm.prank(seller);
        nft.approve(address(marketplace), tokenId);
        
        vm.prank(seller);
        marketplace.listProduct(tokenId, price);
        
        // Seller tries to buy own product
        vm.prank(seller);
        vm.deal(seller, price);
        vm.expectRevert();
        marketplace.buyProduct{value: price}(tokenId);
    }

    function testInsufficientPayment() public {
        // First list the product
        vm.prank(seller);
        nft.approve(address(marketplace), tokenId);
        
        vm.prank(seller);
        marketplace.listProduct(tokenId, price);
        
        // Try to buy with insufficient payment
        vm.prank(buyer);
        vm.deal(buyer, price - 0.1 ether);
        vm.expectRevert();
        marketplace.buyProduct{value: price - 0.1 ether}(tokenId);
    }

    function testRelisting() public {
        // First list the product
        vm.prank(seller);
        nft.approve(address(marketplace), tokenId);
        
        vm.prank(seller);
        marketplace.listProduct(tokenId, price);
        
        // Cancel the listing
        vm.prank(seller);
        marketplace.cancelListing(tokenId);
        
        // Relist with new price
        vm.prank(seller);
        bool success = marketplace.listProduct(tokenId, 2 ether);
        
        assertTrue(success);
        
        // Verify new listing
        IRegenMarketplace.Listing memory listing = marketplace.getListing(tokenId);
        assertTrue(listing.active);
        assertEq(listing.price, 2 ether);
    }

    function testMarketplaceWithoutApproval() public {
        // Try to list without approval
        vm.prank(seller);
        vm.expectRevert();
        marketplace.listProduct(tokenId, price);
    }

    function testRoyaltyDistribution() public {
        // First list the product
        vm.prank(seller);
        nft.approve(address(marketplace), tokenId);
        
        vm.prank(seller);
        marketplace.listProduct(tokenId, price);
        
        // Record balances before purchase
        uint256 sellerBalanceBefore = seller.balance;
        uint256 platformBalanceBefore = platformWallet.balance;
        
        // Buy the product
        vm.prank(buyer);
        vm.deal(buyer, price);
        bool success = marketplace.buyProduct{value: price}(tokenId);
        
        assertTrue(success);
        
        // Calculate expected distribution
        uint256 platformFee = (price * marketplace.platformFeeBps()) / 10000;
        uint256 royaltyAmount = (price * 500) / 10000; // 5% royalty
        
        // Verify payments
        assertEq(platformWallet.balance, platformBalanceBefore + platformFee);
        assertEq(seller.balance, sellerBalanceBefore + price - platformFee - royaltyAmount + royaltyAmount); // Seller also receives royalty
    }
}