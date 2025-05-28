// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../interfaces/IImpactProductNFT.sol";
import "../interfaces/IMarketPlace.sol";

/**
 * @title RegenMarketplace
 * @author Regen Bazaar
 * @notice Marketplace for buying and selling Impact Products
 * @custom:security-contact security@regenbazaar.com
 */
contract RegenMarketplace is IRegenMarketplace, AccessControl, Pausable, ReentrancyGuard {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    address public platformFeeReceiver;
    uint256 public platformFeeBps = 1000;
    
    IImpactProductNFT public impactProductNFT;

    mapping(uint256 => Listing) private _listings;
    uint256[] private _activeListingIds;
    mapping(uint256 => uint256) private _activeListingIndex;
    mapping(address => uint256[]) private _sellerListings;
    
    /**
     * @notice Constructor for the marketplace contract
     * @param impactNFT Address of the ImpactProductNFT contract
     * @param platformWallet Address to receive platform fees
     */
    constructor(address impactNFT, address platformWallet) {
        require(impactNFT != address(0), "Invalid NFT address");
        require(platformWallet != address(0), "Invalid platform wallet");
        
        impactProductNFT = IImpactProductNFT(impactNFT);
        platformFeeReceiver = platformWallet;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
    }
    
    /**
     * @notice Pause marketplace operations
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    /**
     * @notice Unpause marketplace operations
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
    
    /**
     * @notice List an impact product for sale
     * @param tokenId ID of the impact product NFT
     * @param price Listing price in native currency
     * @return success Boolean indicating if the operation was successful
     */
    function listProduct(uint256 tokenId, uint256 price) 
        external 
        whenNotPaused 
        nonReentrant 
        returns (bool success) 
    {
        require(price > 0, "Price must be greater than zero");
        require(impactProductNFT.ownerOf(tokenId) == msg.sender, "Not the token owner");
        require(!_listings[tokenId].active, "Already listed");
        
        require(
            impactProductNFT.getApproved(tokenId) == address(this) || 
            impactProductNFT.isApprovedForAll(msg.sender, address(this)),
            "Marketplace not approved"
        );
       
        _listings[tokenId] = Listing({
            seller: msg.sender,
            tokenId: tokenId,
            price: price,
            active: true,
            listingTime: block.timestamp
        });
 
        _activeListingIds.push(tokenId);
        _activeListingIndex[tokenId] = _activeListingIds.length - 1;

        _sellerListings[msg.sender].push(tokenId);
        
        emit ProductListed(tokenId, msg.sender, price, block.timestamp);
        return true;
    }
    
    /**
     * @notice Update the price of a listed product
     * @param tokenId ID of the listed product
     * @param newPrice Updated price in native currency
     * @return success Boolean indicating if the operation was successful
     */
    function updateListing(uint256 tokenId, uint256 newPrice) 
        external 
        whenNotPaused 
        nonReentrant 
        returns (bool success) 
    {
        require(newPrice > 0, "Price must be greater than zero");
        Listing storage listing = _listings[tokenId];
        
        require(listing.active, "Not listed");
        require(listing.seller == msg.sender, "Not the seller");
        
        listing.price = newPrice;
        
        emit ListingUpdated(tokenId, newPrice);
        return true;
    }
    
    /**
     * @notice Cancel a listing
     * @param tokenId ID of the listed product
     * @return success Boolean indicating if the operation was successful
     */
    function cancelListing(uint256 tokenId) 
        external 
        nonReentrant 
        returns (bool success) 
    {
        Listing storage listing = _listings[tokenId];
        
        require(listing.active, "Not listed");
        require(listing.seller == msg.sender || hasRole(ADMIN_ROLE, msg.sender), "Not authorized");
        
        uint256 lastTokenIndex = _activeListingIds.length - 1;
        uint256 tokenIndex = _activeListingIndex[tokenId];
        
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _activeListingIds[lastTokenIndex];
            _activeListingIds[tokenIndex] = lastTokenId;
            _activeListingIndex[lastTokenId] = tokenIndex;
        }
        
        _activeListingIds.pop();
        delete _activeListingIndex[tokenId];
        
        listing.active = false;
        
        emit ListingCanceled(tokenId, listing.seller);
        return true;
    }
    
    /**
     * @notice Buy a listed impact product
     * @param tokenId ID of the product to purchase
     * @return success Boolean indicating if the operation was successful
     */
    function buyProduct(uint256 tokenId) 
        external 
        payable 
        whenNotPaused 
        nonReentrant 
        returns (bool success) 
    {
        Listing storage listing = _listings[tokenId];
        
        require(listing.active, "Not listed");
        require(msg.sender != listing.seller, "Seller cannot buy own product");
        require(msg.value >= listing.price, "Insufficient payment");
        
        address seller = listing.seller;
        uint256 price = listing.price;
       
        uint256 platformFee = (price * platformFeeBps) / 10000;
        uint256 sellerProceeds = price - platformFee;
        
        (address royaltyReceiver, uint256 royaltyAmount) = impactProductNFT.royaltyInfo(tokenId, price);
        
        if (royaltyAmount > 0 && royaltyReceiver != address(0)) {
            sellerProceeds = sellerProceeds - royaltyAmount;
            
            (bool royaltySuccess, ) = royaltyReceiver.call{value: royaltyAmount}("");
            require(royaltySuccess, "Royalty transfer failed");
        }
        
        uint256 lastTokenIndex = _activeListingIds.length - 1;
        uint256 tokenIndex = _activeListingIndex[tokenId];
        
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _activeListingIds[lastTokenIndex];
            _activeListingIds[tokenIndex] = lastTokenId;
            _activeListingIndex[lastTokenId] = tokenIndex;
        }
        
        _activeListingIds.pop();
        delete _activeListingIndex[tokenId];
        
        listing.active = false;
       
        impactProductNFT.safeTransferFrom(seller, msg.sender, tokenId);
        
        (bool platformSuccess, ) = platformFeeReceiver.call{value: platformFee}("");
        require(platformSuccess, "Platform fee transfer failed");
        
        (bool sellerSuccess, ) = seller.call{value: sellerProceeds}("");
        require(sellerSuccess, "Seller payment failed");
        
        if (msg.value > price) {
            (bool refundSuccess, ) = msg.sender.call{value: msg.value - price}("");
            require(refundSuccess, "Refund failed");
        }
        
        emit ProductSold(tokenId, seller, msg.sender, price, platformFee, royaltyAmount);
        return true;
    }
    
    /**
     * @notice Get listing details for a product
     * @param tokenId ID of the product
     * @return listing The listing details
     */
    function getListing(uint256 tokenId) 
        external 
        view 
        returns (Listing memory listing) 
    {
        return _listings[tokenId];
    }
    
    /**
     * @notice Get all active listings
     * @return tokenIds Array of token IDs with active listings
     */
    function getActiveListings() 
        external 
        view 
        returns (uint256[] memory tokenIds) 
    {
        return _activeListingIds;
    }
    
    /**
     * @notice Get listings by seller
     * @param seller Address of the seller
     * @return tokenIds Array of token IDs listed by this seller
     */
    function getListingsBySeller(address seller) 
        external 
        view 
        returns (uint256[] memory tokenIds) 
    {
        return _sellerListings[seller];
    }
    
    /**
     * @notice Update platform fee percentage
     * @param newFeeBps New platform fee in basis points
     */
    function updatePlatformFee(uint256 newFeeBps) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        require(newFeeBps <= 2000, "Fee too high");
        platformFeeBps = newFeeBps;
    }
    
    /**
     * @notice Update platform fee receiver
     * @param newReceiver New platform fee receiver address
     */
    function updatePlatformFeeReceiver(address newReceiver) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        require(newReceiver != address(0), "Invalid address");
        platformFeeReceiver = newReceiver;
    }
}