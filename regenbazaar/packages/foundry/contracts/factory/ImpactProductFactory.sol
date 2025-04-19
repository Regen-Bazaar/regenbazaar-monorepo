// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../interfaces/IImpactProductNFT.sol";

/**
 * @title ImpactProductFactory
 * @author Regen Bazaar
 * @notice Factory contract for creating Impact Products from real-world impact data
 * @custom:security-contact security@regenbazaar.com
 */
contract ImpactProductFactory is AccessControl, Pausable, ReentrancyGuard {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    
    IImpactProductNFT public impactProductNFT;
    
    // Platform fee settings
    address public platformFeeReceiver;
    uint96 public platformRoyaltyBps = 500; // 5% in basis points
    uint96 public defaultCreatorRoyaltyBps = 500; // 5% in basis points
    
    // Impact calculation parameters
    struct ImpactParams {
        string category;
        uint256 baseMultiplier;  // Base multiplier for the category in basis points
        bool verified;           // Whether this category is verified
    }
    
    // Mapping of impact category to its parameters
    mapping(string => ImpactParams) public impactParameters;
    
    // Whitelisted impact categories
    string[] public impactCategories;
    
    // Events
    event ImpactProductCreated(
        uint256 indexed tokenId, 
        address indexed creator, 
        string category,
        uint256 impactValue,
        uint256 price,
        bool verified
    );
    
    event CategoryAdded(string category, uint256 baseMultiplier);
    event CategoryRemoved(string category);
    event ImpactCalculationParamsUpdated(string category, uint256 baseMultiplier);
    
    /**
     * @notice Constructor for the factory contract
     * @param impactNFT Address of the ImpactProductNFT contract
     * @param platformWallet Address to receive platform fees and royalties
     */
    constructor(address impactNFT, address platformWallet) {
        require(impactNFT != address(0), "Invalid NFT contract");
        require(platformWallet != address(0), "Invalid platform wallet");
        
        impactProductNFT = IImpactProductNFT(impactNFT);
        platformFeeReceiver = platformWallet;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(CREATOR_ROLE, msg.sender);
        _grantRole(VERIFIER_ROLE, msg.sender);
        
        // Add initial impact categories
        _addImpactCategory("Community gardens", 1000); // 1.0x multiplier
        _addImpactCategory("Tree preservation", 2500); // 2.5x multiplier
        _addImpactCategory("Eco tourism", 1500);       // 1.5x multiplier
        _addImpactCategory("Educational programs", 2000); // 2.0x multiplier
        _addImpactCategory("Wildlife Conservation", 3000); // 3.0x multiplier
        _addImpactCategory("CO2 Emissions Reduction", 3500); // 3.5x multiplier
        _addImpactCategory("Waste Management", 1200); // 1.2x multiplier
    }
    
    /**
     * @notice Pause factory operations
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @notice Unpause factory operations
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
    
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
    )
        external
        onlyRole(CREATOR_ROLE)
        whenNotPaused
        nonReentrant
        returns (uint256 tokenId)
    {
        require(baseImpactValue > 0, "Impact value must be positive");
        require(listingPrice > 0, "Price must be positive");
        require(bytes(category).length > 0, "Category cannot be empty");
        require(_isCategorySupported(category), "Unsupported impact category");
        
        // Calculate final impact value with category multiplier
        uint256 finalImpactValue = _calculateImpactValue(category, baseImpactValue);
        
        // Prepare impact data struct
        IImpactProductNFT.ImpactData memory impactData = IImpactProductNFT.ImpactData({
            category: category,
            impactValue: finalImpactValue,
            location: location,
            startDate: startDate,
            endDate: endDate,
            beneficiaries: beneficiaries,
            verified: false, // Initial creation is always unverified
            metadataURI: metadataURI
        });
        
        // Create the impact product NFT
        tokenId = impactProductNFT.createImpactProduct(
            msg.sender,                   // Creator receives the NFT
            impactData,                   // Impact data
            listingPrice,                 // Listing price
            msg.sender,                   // Creator receives royalties
            defaultCreatorRoyaltyBps      // Default creator royalty percentage
        );
        
        emit ImpactProductCreated(
            tokenId,
            msg.sender,
            category,
            finalImpactValue,
            listingPrice, 
            false 
        );
        
        return tokenId;
    }
    
    /**
     * @notice Verify an impact product after validation
     * @param tokenId ID of the token to verify
     * @param validators Array of addresses of validators who confirmed this impact
     * @return success Boolean indicating if the operation was successful
     */
    function verifyImpactProduct(uint256 tokenId, address[] calldata validators)
        external
        onlyRole(VERIFIER_ROLE)
        nonReentrant
        returns (bool success)
    {
        return impactProductNFT.verifyToken(tokenId, validators);
    }
    
    /**
     * @notice Calculate the impact value for a specific category and base value
     * @param category Impact category
     * @param baseValue Raw impact value before applying multipliers
     * @return finalValue The final calculated impact value
     */
    function calculateImpactValue(string calldata category, uint256 baseValue)
        external
        view
        returns (uint256 finalValue)
    {
        require(_isCategorySupported(category), "Unsupported impact category");
        return _calculateImpactValue(category, baseValue);
    }
    
    /**
     * @notice Add a new impact category
     * @param category Name of the new category
     * @param baseMultiplier Base multiplier for the category (in basis points)
     */
    function addImpactCategory(string calldata category, uint256 baseMultiplier)
        external
        onlyRole(ADMIN_ROLE)
    {
        _addImpactCategory(category, baseMultiplier);
    }
    
    /**
     * @notice Remove an impact category
     * @param category Name of the category to remove
     */
    function removeImpactCategory(string calldata category)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(_isCategorySupported(category), "Category does not exist");
        
        // Find and remove the category from the array
        for (uint256 i = 0; i < impactCategories.length; i++) {
            if (keccak256(bytes(impactCategories[i])) == keccak256(bytes(category))) {
                // Replace with the last element and pop
                impactCategories[i] = impactCategories[impactCategories.length - 1];
                impactCategories.pop();
                
                // Remove from mapping
                delete impactParameters[category];
                
                emit CategoryRemoved(category);
                break;
            }
        }
    }
    
    /**
     * @notice Update impact calculation parameters for a category
     * @param category Impact category
     * @param baseMultiplier New base multiplier (in basis points)
     */
    function updateImpactParams(string calldata category, uint256 baseMultiplier)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(_isCategorySupported(category), "Category does not exist");
        require(baseMultiplier > 0, "Multiplier must be positive");
        
        impactParameters[category].baseMultiplier = baseMultiplier;
        
        emit ImpactCalculationParamsUpdated(category, baseMultiplier);
    }
    
    /**
     * @notice Update platform royalty settings
     * @param newRoyaltyBps New platform royalty in basis points
     */
    function updatePlatformRoyalty(uint96 newRoyaltyBps)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(newRoyaltyBps <= 2000, "Platform royalty too high"); // Max 20%
        platformRoyaltyBps = newRoyaltyBps;
    }
    
    /**
     * @notice Update default creator royalty settings
     * @param newRoyaltyBps New creator royalty in basis points
     */
    function updateDefaultCreatorRoyalty(uint96 newRoyaltyBps)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(newRoyaltyBps <= 2000, "Creator royalty too high"); // Max 20%
        defaultCreatorRoyaltyBps = newRoyaltyBps;
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
    
    /**
     * @notice Grant creator role to an address
     * @param creator Address to grant creator role
     */
    function grantCreatorRole(address creator)
        external
        onlyRole(ADMIN_ROLE)
    {
        _grantRole(CREATOR_ROLE, creator);
    }
    
    /**
     * @notice Revoke creator role from an address
     * @param creator Address to revoke creator role
     */
    function revokeCreatorRole(address creator)
        external
        onlyRole(ADMIN_ROLE)
    {
        _revokeRole(CREATOR_ROLE, creator);
    }
    
    /**
     * @notice Get all supported impact categories
     * @return Array of supported category names
     */
    function getSupportedCategories()
        external
        view
        returns (string[] memory)
    {
        return impactCategories;
    }
    
    /**
     * @notice Internal function to add an impact category
     * @param category Name of the category
     * @param baseMultiplier Base multiplier for the category
     */
    function _addImpactCategory(string memory category, uint256 baseMultiplier) internal {
        require(bytes(category).length > 0, "Category cannot be empty");
        require(baseMultiplier > 0, "Multiplier must be positive");
        require(!_isCategorySupported(category), "Category already exists");
        
        // Add to categories array
        impactCategories.push(category);
        
        // Set parameters
        impactParameters[category] = ImpactParams({
            category: category,
            baseMultiplier: baseMultiplier,
            verified: false
        });
        
        emit CategoryAdded(category, baseMultiplier);
    }
    
    /**
     * @notice Internal function to check if a category is supported
     * @param category Name of the category to check
     * @return isSupported True if the category is supported
     */
    function _isCategorySupported(string memory category) internal view returns (bool) {
        return impactParameters[category].baseMultiplier > 0;
    }
    
    /**
     * @notice Internal function to calculate impact value with category multiplier
     * @param category Impact category
     * @param baseValue Raw impact value
     * @return calculatedValue The calculated impact value
     */
    function _calculateImpactValue(string memory category, uint256 baseValue)
        internal
        view
        returns (uint256 calculatedValue)
    {
        ImpactParams memory params = impactParameters[category];
        
        // Apply category multiplier
        calculatedValue = (baseValue * params.baseMultiplier) / 10000; // Divide by 10000 for basis points
        
        return calculatedValue;
    }
}