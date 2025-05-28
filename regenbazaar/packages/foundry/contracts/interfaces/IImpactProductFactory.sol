// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IImpactProductFactory
 * @author Regen Bazaar
 * @notice Interface for the factory contract that creates Impact Products
 * @custom:security-contact security@regenbazaar.com
 */
interface IImpactProductFactory {
    /// @notice Emitted when a new impact product is created through the factory
    event ImpactProductCreated(
        uint256 indexed tokenId,
        address indexed creator,
        string category,
        uint256 impactValue,
        uint256 price,
        bool verified
    );

    /// @notice Emitted when a new impact category is added
    event CategoryAdded(string category, uint256 baseMultiplier);

    /// @notice Emitted when an impact category is removed
    event CategoryRemoved(string category);

    /// @notice Emitted when impact calculation parameters are updated
    event ImpactCalculationParamsUpdated(string category, uint256 baseMultiplier);

    /**
     * @notice Create a new impact product from real-world impact data
     * @param category Impact category
     * @param location Geographic location of the impact
     * @param startDate When the impact activity started
     * @param endDate When the impact activity ended
     * @param beneficiaries Who benefited from this impact
     * @param baseImpactValue Raw impact value before multipliers
     * @param listingPrice Initial listing price
     * @param metadataURI URI for additional metadata
     * @return tokenId ID of the newly created impact product
     */
    function createImpactProduct(
        string calldata category,
        string calldata location,
        uint256 startDate,
        uint256 endDate,
        string calldata beneficiaries,
        uint256 baseImpactValue,
        uint256 listingPrice,
        string calldata metadataURI
    ) external returns (uint256 tokenId);

    /**
     * @notice Verify an impact product after validation
     * @param tokenId ID of the token to verify
     * @param validators Array of addresses of validators who confirmed this impact
     * @return success Boolean indicating if the operation was successful
     */
    function verifyImpactProduct(uint256 tokenId, address[] calldata validators) external returns (bool success);

    /**
     * @notice Calculate the impact value for a specific category and base value
     * @param category Impact category
     * @param baseValue Raw impact value before applying multipliers
     * @return finalValue The final calculated impact value
     */
    function calculateImpactValue(string calldata category, uint256 baseValue)
        external
        view
        returns (uint256 finalValue);

    /**
     * @notice Add a new impact category
     * @param category Name of the new category
     * @param baseMultiplier Base multiplier for the category (in basis points)
     */
    function addImpactCategory(string calldata category, uint256 baseMultiplier) external;

    /**
     * @notice Remove an impact category
     * @param category Name of the category to remove
     */
    function removeImpactCategory(string calldata category) external;

    /**
     * @notice Update impact calculation parameters for a category
     * @param category Impact category
     * @param baseMultiplier New base multiplier (in basis points)
     */
    function updateImpactParams(string calldata category, uint256 baseMultiplier) external;

    /**
     * @notice Get all supported impact categories
     * @return Array of supported category names
     */
    function getSupportedCategories() external view returns (string[] memory);

    /**
     * @notice Grant creator role to an address
     * @param creator Address to grant creator role
     */
    function grantCreatorRole(address creator) external;

    /**
     * @notice Revoke creator role from an address
     * @param creator Address to revoke creator role
     */
    function revokeCreatorRole(address creator) external;
}
