// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

/**
 * @title IImpactProductNFT
 * @author Regen Bazaar
 * @notice Interface for the Impact Product NFT representing tokenized real-world impact
 * @custom:security-contact security@regenbazaar.com
 */
interface IImpactProductNFT is IERC721, IERC2981 {
    /// @notice Emitted when a new impact product is created
    event ImpactProductCreated(
        uint256 indexed tokenId,
        address indexed creator,
        string impactCategory,
        uint256 impactValue,
        string location,
        uint256 price
    );

    /// @notice Emitted when impact data is updated for a token
    event ImpactDataUpdated(uint256 indexed tokenId, uint256 newImpactValue, string newMetadata);

    /// @notice Emitted when a token is verified by validators
    event TokenVerified(uint256 indexed tokenId, address[] validators, uint256 timestamp);

    /// @notice Emitted when royalty information is updated
    event RoyaltyInfoUpdated(uint256 indexed tokenId, address receiver, uint96 royaltyFraction);

    /**
     * @notice Struct containing impact product metadata
     * @param category The impact category (e.g., "Reforestation", "Cleanup")
     * @param impactValue Calculated impact value in basis points
     * @param location Geographic location of the impact
     * @param startDate When the impact activity started
     * @param endDate When the impact activity ended
     * @param beneficiaries Who benefited from this impact // ---- Not a sure abouta this one ---- 
     * @param verified Whether this impact has been verified
     * @param metadataURI Additional metadata URI with extended information
     */
    struct ImpactData {
        string category;
        uint256 impactValue;
        string location;
        uint256 startDate;
        uint256 endDate;
        string beneficiaries;
        bool verified;
        string metadataURI;
    }

    /**
     * @notice Create a new impact product NFT
     * @param to Recipient of the new token
     * @param impactData Struct containing all impact-related information
     * @param price Initial listing price of the impact product
     * @param royaltyReceiver Address to receive royalties
     * @param royaltyFraction Percentage of sales to pay as royalties (in basis points, e.g. 250 = 2.5%)
     * @return tokenId The ID of the newly created token
     */
    function createImpactProduct(
        address to,
        ImpactData calldata impactData,
        uint256 price,
        address royaltyReceiver,
        uint96 royaltyFraction
    ) external returns (uint256 tokenId);

    /**
     * @notice Get the impact data for a specific token
     * @param tokenId ID of the token
     * @return impactData The impact data struct
     */
    function getImpactData(uint256 tokenId) external view returns (ImpactData memory impactData);

    /**
     * @notice Update the impact data for a token (restricted to token creator/authorized entity)
     * @param tokenId ID of the token to update
     * @param newImpactData Updated impact data
     * @return success Boolean indicating if the operation was successful
     */
    function updateImpactData(uint256 tokenId, ImpactData calldata newImpactData) external returns (bool success);

    /**
     * @notice Mark a token as verified after validator consensus
     * @param tokenId ID of the token
     * @param validators Array of addresses of validators who confirmed this impact
     * @return success Boolean indicating if the operation was successful
     */
    function verifyToken(uint256 tokenId, address[] calldata validators) external returns (bool success);

    /**
     * @notice Update the royalty information for a token
     * @param tokenId ID of the token
     * @param receiver Address to receive royalties
     * @param royaltyFraction Percentage of sales to pay as royalties (in basis points)
     */
    function updateRoyaltyInfo(uint256 tokenId, address receiver, uint96 royaltyFraction) external;

    /**
     * @notice Get the current price of an impact product
     * @param tokenId ID of the token
     * @return price Current price of the token
     */
    function getTokenPrice(uint256 tokenId) external view returns (uint256 price);

    /**
     * @notice Update the price of an impact product (only owner or authorized party)
     * @param tokenId ID of the token
     * @param newPrice New price for the token
     */
    function updateTokenPrice(uint256 tokenId, uint256 newPrice) external;

    /**
     * @notice Get all tokens created by a specific NGO/creator
     * @param creator Address of the creator
     * @return tokenIds Array of token IDs created by this creator
     */
    function getTokensByCreator(address creator) external view returns (uint256[] memory tokenIds);

    /**
     * @notice Get all tokens of a specific impact category
     * @param category The impact category to filter by
     * @return tokenIds Array of token IDs in this category
     */
    function getTokensByCategory(string calldata category) external view returns (uint256[] memory tokenIds);

    /**
     * @notice Calculate the impact score for a specific token based on its metadata
     * @param tokenId ID of the token
     * @return score The calculated impact score
     */
    function calculateImpactScore(uint256 tokenId) external view returns (uint256 score);
}
