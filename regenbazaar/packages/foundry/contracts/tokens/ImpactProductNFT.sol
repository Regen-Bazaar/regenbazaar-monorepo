// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../interfaces/IImpactProductNFT.sol";

/**
 * @title ImpactProductNFT
 * @author Regen Bazaar
 * @notice NFT contract representing tokenized real-world impact activities
 * @custom:security-contact security@regenbazaar.com
 */
contract ImpactProductNFT is
    AccessControl,
    Pausable,
    ReentrancyGuard,
    ERC721,
    ERC2981
{
    using Strings for uint256;

    mapping(uint256 => string) private _tokenURIs;
    string private _baseTokenURI;

    uint256[] private _allTokens;
    mapping(uint256 => uint256) private _allTokensIndex;
    mapping(address => uint256[]) private _ownedTokens;
    mapping(uint256 => uint256) private _ownedTokensIndex;

    uint256 private _nextTokenId;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    address public platformFeeReceiver;
    uint96 public platformFeeBps = 1000; 

    mapping(uint256 => ImpactData) private _impactData;

    mapping(uint256 => uint256) private _tokenPrices;

    mapping(address => uint256[]) private _creatorTokens;

    mapping(string => uint256[]) private _categoryTokens;

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

    // Add these event declarations
    event ImpactProductCreated(
        uint256 indexed tokenId,
        address indexed creator,
        string impactCategory,
        uint256 impactValue,
        string location,
        uint256 price
    );

    event ImpactDataUpdated(uint256 indexed tokenId, uint256 newImpactValue, string newMetadata);
    event TokenVerified(uint256 indexed tokenId, address[] validators, uint256 timestamp);
    event RoyaltyInfoUpdated(uint256 indexed tokenId, address receiver, uint96 royaltyFraction);

    /**
     * @notice Constructor for the ImpactProductNFT contract
     * @param platformWallet Address to receive platform fees
     * @param baseTokenURI Base URI for token URIs
     */
    constructor(
        address platformWallet,
        string memory baseTokenURI
    ) ERC721("Regen Bazaar Impact Product", "RIP") {
        require(platformWallet != address(0), "Invalid platform wallet");
        _baseTokenURI = baseTokenURI;

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
    )
        external
        onlyRole(MINTER_ROLE)
        whenNotPaused
        nonReentrant
        returns (uint256 tokenId)
    {
        require(to != address(0), "Cannot mint to zero address");
        require(
            bytes(impactData.category).length > 0,
            "Category cannot be empty"
        );
        require(impactData.impactValue > 0, "Impact value must be positive");
        require(price > 0, "Price must be positive");
        require(royaltyReceiver != address(0), "Invalid royalty receiver");
        require(royaltyFraction <= 1000, "Royalty too high");

        uint256 currentId = _nextTokenId;
        _nextTokenId++;

        _safeMint(to, currentId);

        if (bytes(impactData.metadataURI).length > 0) {
            _setTokenURI(currentId, impactData.metadataURI);
        }

        _impactData[currentId] = impactData;

        _tokenPrices[currentId] = price;

        _setTokenRoyalty(currentId, royaltyReceiver, royaltyFraction);

        _creatorTokens[to].push(currentId);

        _categoryTokens[impactData.category].push(currentId);

        emit ImpactProductCreated(
            currentId,
            to,
            impactData.category,
            impactData.impactValue,
            impactData.location,
            price
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
    function getImpactData(
        uint256 tokenId
    ) external view returns (ImpactData memory) {
        require(_exists(tokenId), "Token does not exist");
        return _impactData[tokenId];
    }

    /**
     * @notice Update the impact data for a token
     * @param tokenId ID of the token to update
     * @param newImpactData Updated impact data
     * @return success Boolean indicating if the operation was successful
     */
    function updateImpactData(
        uint256 tokenId,
        ImpactData calldata newImpactData
    ) external nonReentrant returns (bool success) {
        require(_exists(tokenId), "Token does not exist");
        require(
            ownerOf(tokenId) == msg.sender || hasRole(ADMIN_ROLE, msg.sender),
            "Not authorized to update"
        );

        string memory oldCategory = _impactData[tokenId].category;
        if (
            keccak256(bytes(oldCategory)) !=
            keccak256(bytes(newImpactData.category))
        ) {
            _removeFromCategory(tokenId, oldCategory);

            _categoryTokens[newImpactData.category].push(tokenId);
        }

        _impactData[tokenId] = newImpactData;

        if (bytes(newImpactData.metadataURI).length > 0) {
            _setTokenURI(tokenId, newImpactData.metadataURI);
        }

        emit ImpactDataUpdated(
            tokenId,
            newImpactData.impactValue,
            newImpactData.metadataURI
        );

        return true;
    }

    /**
     * @notice Verify a token after validator consensus
     * @param tokenId ID of the token
     * @param validators Array of addresses of validators who confirmed this impact
     * @return success Boolean indicating if the operation was successful
     */
    function verifyToken(
        uint256 tokenId,
        address[] calldata validators
    )
        external
        onlyRole(VERIFIER_ROLE)
        nonReentrant
        returns (bool success)
    {
        require(_exists(tokenId), "Token does not exist");
        require(validators.length >= 5, "Insufficient validators");
        require(!_impactData[tokenId].verified, "Already verified");

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
    function updateRoyaltyInfo(
        uint256 tokenId,
        address receiver,
        uint96 royaltyFraction
    ) external nonReentrant {
        require(_exists(tokenId), "Token does not exist");
        require(
            ownerOf(tokenId) == msg.sender || hasRole(ADMIN_ROLE, msg.sender),
            "Not authorized to update royalty"
        );
        require(receiver != address(0), "Invalid royalty receiver");
        require(royaltyFraction <= 1000, "Royalty too high");

        _setTokenRoyalty(tokenId, receiver, royaltyFraction);

        emit RoyaltyInfoUpdated(tokenId, receiver, royaltyFraction);
    }

    /**
     * @notice Get the current price of an impact product
     * @param tokenId ID of the token
     * @return price Current price of the token
     */
    function getTokenPrice(
        uint256 tokenId
    ) external view returns (uint256) {
        require(_exists(tokenId), "Token does not exist");
        return _tokenPrices[tokenId];
    }

    /**
     * @notice Update the price of an impact product
     * @param tokenId ID of the token
     * @param newPrice New price for the token
     */
    function updateTokenPrice(
        uint256 tokenId,
        uint256 newPrice
    ) external nonReentrant {
        require(_exists(tokenId), "Token does not exist");
        require(
            ownerOf(tokenId) == msg.sender || hasRole(ADMIN_ROLE, msg.sender),
            "Not authorized to update price"
        );
        require(newPrice > 0, "Price must be positive");

        _tokenPrices[tokenId] = newPrice;
    }

    /**
     * @notice Get all tokens created by a specific NGO/creator
     * @param creator Address of the creator
     * @return tokenIds Array of token IDs created by this creator
     */
    function getTokensByCreator(
        address creator
    ) external view returns (uint256[] memory) {
        return _creatorTokens[creator];
    }

    /**
     * @notice Get all tokens of a specific impact category
     * @param category The impact category to filter by
     * @return tokenIds Array of token IDs in this category
     */
    function getTokensByCategory(
        string calldata category
    ) external view returns (uint256[] memory) {
        return _categoryTokens[category];
    }

    /**
     * @notice Calculate impact score for a token based on its metadata
     * @param tokenId ID of the token
     * @return score The calculated impact score
     */
    function calculateImpactScore(
        uint256 tokenId
    ) external view returns (uint256 score) {
        require(_exists(tokenId), "Token does not exist");

        ImpactData memory data = _impactData[tokenId];

        score = data.impactValue;

        if (data.verified) {
            score = (score * 12) / 10;
        }

        if (data.endDate > data.startDate) {
            uint256 duration = data.endDate - data.startDate;
            if (duration > 30 days) {
                score = (score * 11) / 10;
            }
            if (duration > 180 days) {
                score = (score * 12) / 10;
            }
        }

        return score;
    }

    /**
     * @notice Utility function to remove a token from a category array
     * @param tokenId Token ID to remove
     * @param category Category to remove from
     */
    function _removeFromCategory(
        uint256 tokenId,
        string memory category
    ) private {
        uint256[] storage categoryList = _categoryTokens[category];
        for (uint256 i = 0; i < categoryList.length; i++) {
            if (categoryList[i] == tokenId) {
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
    function setPlatformFeeReceiver(
        address newReceiver
    ) external onlyRole(ADMIN_ROLE) {
        require(newReceiver != address(0), "Invalid address");
        platformFeeReceiver = newReceiver;
    }

    /**
     * @notice Set the platform fee percentage (in basis points)
     * @param newFeeBps New fee in basis points (e.g., 1000 = 10%)
     */
    function setPlatformFeeBps(uint96 newFeeBps) external onlyRole(ADMIN_ROLE) {
        require(newFeeBps <= 3000, "Fee too high"); 
        platformFeeBps = newFeeBps;
    }

    /**
     * @notice Check if the contract supports an interface
     * @param interfaceId Interface identifier
     * @return True if the interface is supported
     */
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721, ERC2981, AccessControl)
        returns (bool)
    {
        return
            interfaceId == type(IImpactProductNFT).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @notice Handle token transfers including pausing and enumeration
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal virtual whenNotPaused {
        if (from == address(0)) {
            _addTokenToAllTokensEnumeration(tokenId);
        } else if (from != to) {
            _removeTokenFromOwnerEnumeration(from, tokenId);
        }
        if (to == address(0)) {
            _removeTokenFromAllTokensEnumeration(tokenId);
        } else if (to != from) {
            _addTokenToOwnerEnumeration(to, tokenId);
        }
    }

    /**
     * @dev Required override for _burn from both ERC721URIStorage and ERC721Enumerable
     */
    function  _burn(
        uint256 tokenId
    ) internal override {
        super._burn(tokenId);

        // Clear royalty information
        _resetTokenRoyalty(tokenId);
    }

    /**
     * @dev Required override for tokenURI from ERC721URIStorage
     */
    function tokenURI(
        uint256 tokenId
    ) public override view returns (string memory) {
        require(_exists(tokenId), "URI query for nonexistent token");

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }
        return string(abi.encodePacked(base, tokenId.toString()));
    }

    function _baseURI() internal override view virtual returns (string memory) {
        return _baseTokenURI;
    }

    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId];
        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId;
        _allTokensIndex[lastTokenId] = tokenIndex;

        _allTokens.pop();
        delete _allTokensIndex[tokenId];
    }

    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = balanceOf(to);
        _ownedTokens[to].push(tokenId);
        _ownedTokensIndex[tokenId] = length;
    }

    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        uint256 lastTokenIndex = balanceOf(from) - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];
            _ownedTokens[from][tokenIndex] = lastTokenId;
            _ownedTokensIndex[lastTokenId] = tokenIndex;
        }

        _ownedTokens[from].pop();
        delete _ownedTokensIndex[tokenId];
    }

    function totalSupply() public view returns (uint256) {
        return _allTokens.length;
    }

    function tokenByIndex(uint256 index) public view returns (uint256) {
        require(index < _allTokens.length, "Index out of bounds");
        return _allTokens[index];
    }

    function tokenOfOwnerByIndex(address owner, uint256 index) public view returns (uint256) {
        require(index < balanceOf(owner), "Index out of bounds");
        return _ownedTokens[owner][index];
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens start existing when they are minted, and stop existing when they are burned.
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    /**
     * @dev Sets `_tokenURI` as the tokenURI of `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        require(_exists(tokenId), "ERC721URIStorage: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }
}
