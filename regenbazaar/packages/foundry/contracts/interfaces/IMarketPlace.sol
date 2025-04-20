// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IRegenMarketplace
 * @author Regen Bazaar
 * @notice Interface for the Regen Bazaar marketplace
 * @custom:security-contact security@regenbazaar.com
 */
interface IRegenMarketplace {
    /**
     * @notice Struct containing listing details
     * @param seller Address of the seller
     * @param tokenId ID of the impact product
     * @param price Listing price in native currency
     * @param active Whether the listing is currently active
     * @param listingTime When the listing was created
     */
    struct Listing {
        address seller;
        uint256 tokenId;
        uint256 price;
        bool active;
        uint256 listingTime;
    }

    /// @notice Emitted when an impact product is listed
    event ProductListed(uint256 indexed tokenId, address indexed seller, uint256 price, uint256 listingTime);
    
    /// @notice Emitted when a listing is updated
    event ListingUpdated(uint256 indexed tokenId, uint256 newPrice);
    
    /// @notice Emitted when a listing is canceled
    event ListingCanceled(uint256 indexed tokenId, address indexed seller);
    
    /// @notice Emitted when an impact product is sold
    event ProductSold(
        uint256 indexed tokenId, 
        address indexed seller, 
        address indexed buyer, 
        uint256 price, 
        uint256 platformFee,
        uint256 creatorFee
    );

    /**
     * @notice List an impact product for sale
     * @param tokenId ID of the impact product NFT
     * @param price Listing price in native currency
     * @return success Boolean indicating if the operation was successful
     */
    function listProduct(uint256 tokenId, uint256 price) external returns (bool success);
    
    /**
     * @notice Update the price of a listed product
     * @param tokenId ID of the listed product
     * @param newPrice Updated price in native currency
     * @return success Boolean indicating if the operation was successful
     */
    function updateListing(uint256 tokenId, uint256 newPrice) external returns (bool success);
    
    /**
     * @notice Cancel a listing
     * @param tokenId ID of the listed product
     * @return success Boolean indicating if the operation was successful
     */
    function cancelListing(uint256 tokenId) external returns (bool success);
    
    /**
     * @notice Buy a listed impact product
     * @param tokenId ID of the product to purchase
     * @return success Boolean indicating if the operation was successful
     */
    function buyProduct(uint256 tokenId) external payable returns (bool success);
    
    /**
     * @notice Get listing details for a product
     * @param tokenId ID of the product
     * @return listing The listing details
     */
    function getListing(uint256 tokenId) external view returns (Listing memory listing);
    
    /**
     * @notice Get all active listings
     * @return tokenIds Array of token IDs with active listings
     */
    function getActiveListings() external view returns (uint256[] memory tokenIds);
    
    /**
     * @notice Get listings by seller
     * @param seller Address of the seller
     * @return tokenIds Array of token IDs listed by this seller
     */
    function getListingsBySeller(address seller) external view returns (uint256[] memory tokenIds);
}