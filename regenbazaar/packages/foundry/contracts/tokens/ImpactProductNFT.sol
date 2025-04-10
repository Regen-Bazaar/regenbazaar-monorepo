// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
// import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../interfaces/IImpactProductNFT.sol";

/**
 * @title ImpactProductNFT
 * @author Regen Bazaar
 * @notice NFT contract representing tokenized real-world impact activities
 * @custom:security-contact security@regenbazaar.com
 */
contract ImpactProductNFT is
    IImpactProductNFT,
    ERC721Enumerable,
    ERC721URIStorage,
    ERC2981,
    AccessControl,
    Pausable,
    ReentrancyGuard
{
    // using Counters for Counters.Counter;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // Token counter for assigning IDs
    Counters.Counter private _tokenIdCounter;

    // Platform fee receiver
    address public platformFeeReceiver;
    uint96 public platformFeeBps = 1000; // 10% in basis points

    // Mapping tokenId to impact data
    mapping(uint256 => ImpactData) private _impactData;

    // Mapping tokenId to price
    mapping(uint256 => uint256) private _tokenPrices;

    // Mapping creator to their tokens
    mapping(address => uint256[]) private _creatorTokens;

    // Mapping category to token IDs
    mapping(string => uint256[]) private _categoryTokens;

    /**
     * @notice Constructor for the ImpactProductNFT contract
     * @param platformWallet Address to receive platform fees
     */
    constructor(address platformWallet) ERC721("Regen Bazaar Impact Product", "RIP") {
        require(platformWallet != address(0), "Invalid platform wallet");

        platformFeeReceiver = platformWallet;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(VERIFIER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }

    /**
     * @notice Create a new impact product NFT
     * @param to Recipient of the new token
     * @param impactData Struct containing all impact-related information
     * @param price Initial listing price of the impact product
     * @param royaltyReceiver Address to receive royalties
     * @param royaltyFraction Percentage of sales to pay as royalties (in basis points)
     * @return tokenId The ID of the newly created token
     */
    function createImpactProduct(
        address to,
        ImpactData calldata impactData,
        uint256 price,
        address royaltyReceiver,
        uint96 royaltyFraction
    ) external override onlyRole(MINTER_ROLE) whenNotPaused nonReentrant returns (uint256 tokenId) {
        require(to != address(0), "Cannot mint to zero address");
        require(bytes(impactData.category).length > 0, "Category cannot be empty");
        require(impactData.impactValue > 0, "Impact value must be positive");
        require(price > 0, "Price must be positive");
        require(royaltyReceiver != address(0), "Invalid royalty receiver");
        require(royaltyFraction <= 1000, "Royalty too high"); // Max 10%

        // Get new token ID
        uint256 currentId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        // Mint token
        _safeMint(to, currentId);

        // Set token metadata URI if provided
        if (bytes(impactData.metadataURI).length > 0) {
            _setTokenURI(currentId, impactData.metadataURI);
        }

        // Store impact data
        _impactData[currentId] = impactData;

        // Set token price
        _tokenPrices[currentId] = price;

        // Set royalty info (split between creator and platform)
        // Creator gets their defined royalty percentage
        _setTokenRoyalty(currentId, royaltyReceiver, royaltyFraction);

        // Track token by creator
        _creatorTokens[to].push(currentId);

        // Track token by category
        _categoryTokens[impactData.category].push(currentId);

        emit ImpactProductCreated(
            currentId, to, impactData.category, impactData.impactValue, impactData.location, price
        );

        return currentId;
    }

    /**
     * @notice Pause token minting and transfers
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause token minting and transfers
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @notice Get the impact data for a specific token
     * @param tokenId ID of the token
     * @return Data struct with all impact information
     */
    function getImpactData(uint256 tokenId) external view override returns (ImpactData memory) {
        require(_exists(tokenId), "Token does not exist");
        return _impactData[tokenId];
    }

    /**
     * @notice Update the impact data for a token
     * @param tokenId ID of the token to update
     * @param newImpactData Updated impact data
     * @return success Boolean indicating if the operation was successful
     */
    function updateImpactData(uint256 tokenId, ImpactData calldata newImpactData)
        external
        override
        nonReentrant
        returns (bool success)
    {
        require(_exists(tokenId), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender || hasRole(ADMIN_ROLE, msg.sender), "Not authorized to update");

        // Update the category tracking if it has changed
        string memory oldCategory = _impactData[tokenId].category;
        if (keccak256(bytes(oldCategory)) != keccak256(bytes(newImpactData.category))) {
            // Remove from old category
            _removeFromCategory(tokenId, oldCategory);

            // Add to new category
            _categoryTokens[newImpactData.category].push(tokenId);
        }

        // Update the impact data
        _impactData[tokenId] = newImpactData;

        // Update token URI if provided
        if (bytes(newImpactData.metadataURI).length > 0) {
            _setTokenURI(tokenId, newImpactData.metadataURI);
        }

        emit ImpactDataUpdated(tokenId, newImpactData.impactValue, newImpactData.metadataURI);

        return true;
    }

    /**
     * @notice Verify a token after validator consensus
     * @param tokenId ID of the token
     * @param validators Array of addresses of validators who confirmed this impact
     * @return success Boolean indicating if the operation was successful
     */
    function verifyToken(uint256 tokenId, address[] calldata validators)
        external
        override
        onlyRole(VERIFIER_ROLE)
        nonReentrant
        returns (bool success)
    {
        require(_exists(tokenId), "Token does not exist");
        require(validators.length >= 5, "Insufficient validators");
        require(!_impactData[tokenId].verified, "Already verified");

        // Update verified status
        _impactData[tokenId].verified = true;

        emit TokenVerified(tokenId, validators, block.timestamp);

        return true;
    }

    /**
     * @notice Update the royalty information for a token
     * @param tokenId ID of the token
     * @param receiver Address to receive royalties
     * @param royaltyFraction Percentage of sales to pay as royalties (in basis points)
     */
    function updateRoyaltyInfo(uint256 tokenId, address receiver, uint96 royaltyFraction)
        external
        override
        nonReentrant
    {
        require(_exists(tokenId), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender || hasRole(ADMIN_ROLE, msg.sender), "Not authorized to update royalty");
        require(receiver != address(0), "Invalid royalty receiver");
        require(royaltyFraction <= 1000, "Royalty too high"); // Max 10%

        _setTokenRoyalty(tokenId, receiver, royaltyFraction);

        emit RoyaltyInfoUpdated(tokenId, receiver, royaltyFraction);
    }

    /**
     * @notice Get the current price of an impact product
     * @param tokenId ID of the token
     * @return price Current price of the token
     */
    function getTokenPrice(uint256 tokenId) external view override returns (uint256) {
        require(_exists(tokenId), "Token does not exist");
        return _tokenPrices[tokenId];
    }

    /**
     * @notice Update the price of an impact product
     * @param tokenId ID of the token
     * @param newPrice New price for the token
     */
    function updateTokenPrice(uint256 tokenId, uint256 newPrice) external override nonReentrant {
        require(_exists(tokenId), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender || hasRole(ADMIN_ROLE, msg.sender), "Not authorized to update price");
        require(newPrice > 0, "Price must be positive");

        _tokenPrices[tokenId] = newPrice;
    }

    /**
     * @notice Get all tokens created by a specific NGO/creator
     * @param creator Address of the creator
     * @return tokenIds Array of token IDs created by this creator
     */
    function getTokensByCreator(address creator) external view override returns (uint256[] memory) {
        return _creatorTokens[creator];
    }

    /**
     * @notice Get all tokens of a specific impact category
     * @param category The impact category to filter by
     * @return tokenIds Array of token IDs in this category
     */
    function getTokensByCategory(string calldata category) external view override returns (uint256[] memory) {
        return _categoryTokens[category];
    }

    /**
     * @notice Calculate impact score for a token based on its metadata
     * @param tokenId ID of the token
     * @return score The calculated impact score
     */
    function calculateImpactScore(uint256 tokenId) external view override returns (uint256 score) {
        require(_exists(tokenId), "Token does not exist");

        ImpactData memory data = _impactData[tokenId];

        // Basic impact score is the impact value
        score = data.impactValue;

        // Apply multipliers and adjustments based on verification status and other factors
        if (data.verified) {
            score = score * 12 / 10; // +20% for verified impact
        }

        // Add time-based multiplier (higher for longer impact durations)
        if (data.endDate > data.startDate) {
            uint256 duration = data.endDate - data.startDate;
            if (duration > 30 days) {
                score = score * 11 / 10; // +10% for >1 month activities
            }
            if (duration > 180 days) {
                score = score * 12 / 10; // +20% for >6 month activities
            }
        }

        return score;
    }

    /**
     * @notice Utility function to remove a token from a category array
     * @param tokenId Token ID to remove
     * @param category Category to remove from
     */
    function _removeFromCategory(uint256 tokenId, string memory category) private {
        uint256[] storage categoryList = _categoryTokens[category];
        for (uint256 i = 0; i < categoryList.length; i++) {
            if (categoryList[i] == tokenId) {
                // Replace with the last element and pop
                categoryList[i] = categoryList[categoryList.length - 1];
                categoryList.pop();
                break;
            }
        }
    }

    /**
     * @notice Set the platform fee receiver address
     * @param newReceiver New platform fee receiver address
     */
    function setPlatformFeeReceiver(address newReceiver) external onlyRole(ADMIN_ROLE) {
        require(newReceiver != address(0), "Invalid address");
        platformFeeReceiver = newReceiver;
    }

    /**
     * @notice Set the platform fee percentage (in basis points)
     * @param newFeeBps New fee in basis points (e.g., 1000 = 10%)
     */
    function setPlatformFeeBps(uint96 newFeeBps) external onlyRole(ADMIN_ROLE) {
        require(newFeeBps <= 3000, "Fee too high"); // Max 30%
        platformFeeBps = newFeeBps;
    }

    /**
     * @notice Check if the contract supports an interface
     * @param interfaceId Interface identifier
     * @return True if the interface is supported
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC2981, AccessControl, IERC165)
        returns (bool)
    {
        return interfaceId == type(IImpactProductNFT).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @notice Override _beforeTokenTransfer to handle pausing and enumeration
     */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        override(ERC721, ERC721Enumerable)
        whenNotPaused
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    /**
     * @dev Required override for _burn from both ERC721URIStorage and ERC721Enumerable
     */
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);

        // Clear royalty information
        _resetTokenRoyalty(tokenId);
    }

    /**
     * @dev Required override for tokenURI from ERC721URIStorage
     */
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }
}
